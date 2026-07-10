use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Duration;

use anyhow::{anyhow, Context, Result};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::TcpStream;
use tokio::sync::{mpsc, oneshot, watch, Mutex};
use tokio::time::{sleep_until, timeout, Instant};
use tracing::{debug, info, warn};

const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);
const WELCOME_TIMEOUT: Duration = Duration::from_secs(5);
const COMMAND_TIMEOUT: Duration = Duration::from_secs(15);
const QUEUE_TIMEOUT: Duration = Duration::from_secs(5);

struct Request {
    command: String,
    response_sender: oneshot::Sender<Result<Vec<HashMap<String, String>>>>,
}

struct QueryConnection {
    id: u64,
    sender: mpsc::Sender<Request>,
    shutdown: watch::Sender<bool>,
}

pub struct QueryClient {
    connection: Option<QueryConnection>,
}

lazy_static::lazy_static! {
    pub static ref QUERY_CLIENT: Arc<Mutex<QueryClient>> = Arc::new(Mutex::new(QueryClient { connection: None }));
    static ref CONNECT_GUARD: Mutex<()> = Mutex::new(());
}

static NEXT_CONNECTION_ID: AtomicU64 = AtomicU64::new(1);

/// Unescapes a TeamSpeak 3 ServerQuery string.
pub fn unescape(s: &str) -> String {
    let mut result = String::with_capacity(s.len());
    let mut chars = s.chars();

    while let Some(character) = chars.next() {
        if character != '\\' {
            result.push(character);
            continue;
        }

        match chars.next() {
            Some('s') => result.push(' '),
            Some('p') => result.push('|'),
            Some('n') => result.push('\n'),
            Some('f') => result.push('\x0C'),
            Some('r') => result.push('\r'),
            Some('t') => result.push('\t'),
            Some('v') => result.push('\x0B'),
            Some('/') => result.push('/'),
            Some('\\') => result.push('\\'),
            Some(other) => {
                result.push('\\');
                result.push(other);
            }
            None => result.push('\\'),
        }
    }

    result
}

/// Escapes a string for TeamSpeak 3 ServerQuery.
pub fn escape(s: &str) -> String {
    let mut result = String::with_capacity(s.len() + s.len() / 4);
    for character in s.chars() {
        match character {
            '\\' => result.push_str(r"\\"),
            '/' => result.push_str(r"\/"),
            '|' => result.push_str(r"\p"),
            '\n' => result.push_str(r"\n"),
            '\r' => result.push_str(r"\r"),
            '\t' => result.push_str(r"\t"),
            '\x0B' => result.push_str(r"\v"),
            '\x0C' => result.push_str(r"\f"),
            ' ' => result.push_str(r"\s"),
            _ => result.push(character),
        }
    }
    result
}

/// Parses a raw ServerQuery response into a list of key/value maps.
pub fn parse_response(raw: &str) -> Vec<HashMap<String, String>> {
    raw.trim()
        .split('|')
        .filter(|entry| !entry.is_empty())
        .map(|entry| {
            entry
                .split(' ')
                .filter(|pair| !pair.is_empty())
                .map(|pair| match pair.split_once('=') {
                    Some((key, value)) => (key.to_string(), unescape(value)),
                    None => (pair.to_string(), String::new()),
                })
                .collect()
        })
        .collect()
}

impl QueryClient {
    pub async fn connect(
        ip: &str,
        query_port: u16,
        virtual_server_port: u16,
        user: &str,
        pass: &str,
    ) -> Result<String> {
        if user.is_empty() != pass.is_empty() {
            return Err(anyhow!(
                "ServerQuery username and password must either both be provided or both be empty"
            ));
        }

        let _connect_guard = CONNECT_GUARD.lock().await;
        Self::disconnect().await;

        let address = format!("{ip}:{query_port}");
        info!("Connecting to ServerQuery at {address}");
        let stream = timeout(CONNECT_TIMEOUT, TcpStream::connect(&address))
            .await
            .context("Timed out while connecting to ServerQuery")?
            .with_context(|| format!("Failed to connect to ServerQuery at {address}"))?;
        let (read_half, write_half) = stream.into_split();
        let mut reader = BufReader::new(read_half);

        for _ in 0..2 {
            let mut line = String::new();
            let byte_count = timeout(WELCOME_TIMEOUT, reader.read_line(&mut line))
                .await
                .context("Timed out while reading the ServerQuery welcome message")??;
            if byte_count == 0 {
                return Err(anyhow!(
                    "ServerQuery closed before sending its welcome message"
                ));
            }
        }

        let (sender, receiver) = mpsc::channel::<Request>(100);
        let (shutdown, shutdown_receiver) = watch::channel(false);
        let connection_id = NEXT_CONNECTION_ID.fetch_add(1, Ordering::Relaxed);
        {
            let mut client = QUERY_CLIENT.lock().await;
            client.connection = Some(QueryConnection {
                id: connection_id,
                sender: sender.clone(),
                shutdown,
            });
        }

        tokio::spawn(async move {
            Self::run_worker(reader, write_half, receiver, shutdown_receiver).await;
            Self::clear_connection(connection_id).await;
        });

        if !user.is_empty() {
            let login_command = format!("login {} {}", escape(user), escape(pass));
            if let Err(error) = Self::send_command(&login_command).await {
                Self::disconnect().await;
                return Err(anyhow!("ServerQuery login failed: {error}"));
            }
        }

        if let Err(error) = Self::send_command(&format!("use port={virtual_server_port}")).await {
            Self::disconnect().await;
            return Err(anyhow!(
                "Failed to select virtual server port {virtual_server_port}: {error}"
            ));
        }

        Ok("Connected".to_string())
    }

    pub async fn send_command(command: &str) -> Result<String> {
        let parsed = Self::send_command_parsed(command).await?;
        serde_json::to_string(&parsed).context("Failed to serialize ServerQuery response")
    }

    pub async fn send_command_parsed(command: &str) -> Result<Vec<HashMap<String, String>>> {
        let sender = {
            let client = QUERY_CLIENT.lock().await;
            client
                .connection
                .as_ref()
                .map(|connection| connection.sender.clone())
        }
        .ok_or_else(|| anyhow!("Not connected to ServerQuery"))?;

        let (response_sender, response_receiver) = oneshot::channel();
        let request = Request {
            command: command.to_string(),
            response_sender,
        };
        timeout(QUEUE_TIMEOUT, sender.send(request))
            .await
            .context("Timed out while queuing ServerQuery command")?
            .map_err(|_| anyhow!("ServerQuery connection is closed"))?;

        timeout(COMMAND_TIMEOUT + Duration::from_secs(1), response_receiver)
            .await
            .context("Timed out while waiting for ServerQuery response")?
            .map_err(|_| anyhow!("ServerQuery command worker stopped"))?
    }

    pub async fn disconnect() {
        let connection = {
            let mut client = QUERY_CLIENT.lock().await;
            client.connection.take()
        };
        if let Some(connection) = connection {
            let _ = connection.shutdown.send(true);
        }
    }

    pub async fn is_connected() -> bool {
        QUERY_CLIENT.lock().await.connection.is_some()
    }

    async fn run_worker(
        mut reader: BufReader<tokio::net::tcp::OwnedReadHalf>,
        mut writer: tokio::net::tcp::OwnedWriteHalf,
        mut receiver: mpsc::Receiver<Request>,
        mut shutdown: watch::Receiver<bool>,
    ) {
        let mut active_request: Option<Request> = None;
        let mut active_deadline: Option<Instant> = None;
        let mut response_lines: Vec<String> = Vec::new();
        let mut line_buffer = String::new();

        loop {
            let timeout_deadline =
                active_deadline.unwrap_or_else(|| Instant::now() + Duration::from_secs(86_400));
            tokio::select! {
                changed = shutdown.changed() => {
                    if changed.is_err() || *shutdown.borrow() {
                        break;
                    }
                }
                _ = sleep_until(timeout_deadline), if active_request.is_some() => {
                    if let Some(request) = active_request.take() {
                        let _ = request.response_sender.send(Err(anyhow!("Timed out waiting for ServerQuery response")));
                    }
                    break;
                }
                request = receiver.recv(), if active_request.is_none() => {
                    match request {
                        Some(request) => {
                            debug!("Sending ServerQuery command: {}", redact_command(&request.command));
                            let command = format!("{}\n", request.command);
                            if let Err(error) = writer.write_all(command.as_bytes()).await {
                                let _ = request.response_sender.send(Err(anyhow!("Failed to write ServerQuery command: {error}")));
                                break;
                            }
                            active_deadline = Some(Instant::now() + COMMAND_TIMEOUT);
                            active_request = Some(request);
                            response_lines.clear();
                        }
                        None => break,
                    }
                }
                read_result = reader.read_line(&mut line_buffer) => {
                    match read_result {
                        Ok(0) => {
                            warn!("ServerQuery disconnected");
                            break;
                        }
                        Ok(_) => {
                            let line = line_buffer.trim();
                            if line.is_empty() {
                                line_buffer.clear();
                                continue;
                            }
                            if line.starts_with("notify") {
                                debug!("Ignoring ServerQuery notification: {line}");
                            } else if line.starts_with("error") {
                                if let Some(request) = active_request.take() {
                                    let parsed_error = parse_response(line);
                                    let is_error = parsed_error
                                        .first()
                                        .and_then(|entry| entry.get("id"))
                                        .is_some_and(|id| id != "0");
                                    if is_error {
                                        let _ = request.response_sender.send(Err(anyhow!("ServerQuery command failed: {line}")));
                                    } else {
                                        let mut parsed_response = Vec::new();
                                        if response_lines.is_empty() {
                                            parsed_response.push(HashMap::from([(
                                                "status".to_string(),
                                                "ok".to_string(),
                                            )]));
                                        }
                                        for response_line in &response_lines {
                                            parsed_response.extend(parse_response(response_line));
                                        }
                                        let _ = request.response_sender.send(Ok(parsed_response));
                                    }
                                    active_deadline = None;
                                }
                            } else if active_request.is_some() {
                                response_lines.push(line.to_string());
                            } else {
                                debug!("Ignoring orphaned ServerQuery response");
                            }
                            line_buffer.clear();
                        }
                        Err(error) => {
                            warn!("ServerQuery read error: {error}");
                            break;
                        }
                    }
                }
            }
        }

        if let Some(request) = active_request {
            let _ = request.response_sender.send(Err(anyhow!(
                "ServerQuery connection closed while awaiting response"
            )));
        }
        while let Ok(request) = receiver.try_recv() {
            let _ = request.response_sender.send(Err(anyhow!(
                "ServerQuery connection closed before command was sent"
            )));
        }
    }

    async fn clear_connection(connection_id: u64) {
        let mut client = QUERY_CLIENT.lock().await;
        if client
            .connection
            .as_ref()
            .is_some_and(|connection| connection.id == connection_id)
        {
            client.connection = None;
        }
    }
}

fn redact_command(command: &str) -> String {
    if command.starts_with("login ") {
        "login [REDACTED]".to_string()
    } else {
        command.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::{escape, parse_response, redact_command, unescape};

    #[test]
    fn escapes_and_unescapes_server_query_values() {
        let source = "name with | slash/\\\n";
        assert_eq!(unescape(&escape(source)), source);
    }

    #[test]
    fn parses_multiple_server_query_records() {
        let parsed = parse_response("clid=1 client_nickname=Alice|clid=2 client_nickname=Bob");
        assert_eq!(parsed.len(), 2);
        assert_eq!(parsed[0]["client_nickname"], "Alice");
        assert_eq!(parsed[1]["clid"], "2");
    }

    #[test]
    fn redacts_login_commands() {
        assert_eq!(redact_command("login admin secret"), "login [REDACTED]");
    }
}
