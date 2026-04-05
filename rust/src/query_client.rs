use anyhow::{anyhow, Result};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::TcpStream;
use tokio::sync::{mpsc, oneshot, Mutex};
use tracing::{debug, info, warn};

// Command request wrapper for the internal queue
struct Request {
    command: String,
    response_sender: oneshot::Sender<Result<Vec<HashMap<String, String>>>>,
}

pub struct QueryClient {
    tx: Option<mpsc::Sender<Request>>,
}

lazy_static::lazy_static! {
    pub static ref QUERY_CLIENT: Arc<Mutex<QueryClient>> = Arc::new(Mutex::new(QueryClient { tx: None }));
}

/// Unescapes a TeamSpeak 3 ServerQuery string
pub fn unescape(s: &str) -> String {
    let mut result = String::with_capacity(s.len());
    let mut chars = s.chars().peekable();

    while let Some(c) = chars.next() {
        if c == '\\' {
            if let Some(next) = chars.next() {
                match next {
                    's' => result.push(' '),
                    'p' => result.push('|'),
                    'n' => result.push('\n'),
                    'f' => result.push('\x0C'),
                    'r' => result.push('\r'),
                    't' => result.push('\t'),
                    'v' => result.push('\x0B'),
                    '/' => result.push('/'),
                    '\\' => result.push('\\'),
                    _ => {
                        result.push('\\');
                        result.push(next);
                    }
                }
            } else {
                result.push('\\');
            }
        } else {
            result.push(c);
        }
    }
    result
}

/// Escapes a string for TeamSpeak 3 ServerQuery
pub fn escape(s: &str) -> String {
    let mut result = String::with_capacity(s.len() + s.len() / 4);
    for c in s.chars() {
        match c {
            '\\' => result.push_str(r"\\"),
            '/' => result.push_str(r"\/"),
            '|' => result.push_str(r"\p"),
            '\n' => result.push_str(r"\n"),
            '\r' => result.push_str(r"\r"),
            '\t' => result.push_str(r"\t"),
            '\x0B' => result.push_str(r"\v"),
            '\x0C' => result.push_str(r"\f"),
            ' ' => result.push_str(r"\s"),
            _ => result.push(c),
        }
    }
    result
}

/// Parses a raw ServerQuery response into a list of HashMaps.
pub fn parse_response(raw: &str) -> Vec<HashMap<String, String>> {
    let mut entries = Vec::new();
    let raw = raw.trim();
    if raw.is_empty() {
        return entries;
    }

    for entry in raw.split('|') {
        let mut map = HashMap::new();
        for kv in entry.split(' ') {
            if kv.is_empty() {
                continue;
            }
            if let Some((k, v)) = kv.split_once('=') {
                map.insert(k.to_string(), unescape(v));
            } else {
                map.insert(kv.to_string(), String::new());
            }
        }
        entries.push(map);
    }

    // Merge first entry's values into the others as in TS3-NodeJS-Library
    // We remove this because TS3 actually returns unique keys per item, 
    // and merging causes massive data duplication (e.g. channel descriptions copying to all channels).
    
    entries
}

impl QueryClient {
    pub async fn connect(ip: &str, port: u16, user: &str, pass: &str) -> Result<String> {
        let mut client = QUERY_CLIENT.lock().await;
        
        // Disconnect existing if any
        if let Some(_) = client.tx {
            client.tx = None; 
        }

        let addr = format!("{}:{}", ip, port);
        info!("Connecting to ServerQuery at {}", addr);
        
        let stream = TcpStream::connect(&addr).await?;
        let (read_half, mut write_half) = stream.into_split();
        let mut reader = BufReader::new(read_half);
        
        // Read TS3 Server Query Welcome Message
        let mut line = String::new();
        reader.read_line(&mut line).await?;
        line.clear();
        reader.read_line(&mut line).await?;

        // Set up the event loop queue
        let (tx, mut rx) = mpsc::channel::<Request>(100);
        client.tx = Some(tx.clone());

        // Spawn background worker mimicking TS3-NodeJS-Library queueWorker
        tokio::spawn(async move {
            let mut active_req: Option<Request> = None;
            let mut current_response: Vec<String> = Vec::new();
            let mut line_buf = String::new();

            loop {
                tokio::select! {
                    // Try to pick next request from queue if idle
                    req_opt = rx.recv(), if active_req.is_none() => {
                        if let Some(req) = req_opt {
                            debug!("Queue Worker sending: {}", req.command);
                            let cmd_str = format!("{}\n", req.command);
                            if let Err(e) = write_half.write_all(cmd_str.as_bytes()).await {
                                let _ = req.response_sender.send(Err(anyhow!("Socket write failed: {}", e)));
                                break;
                            }
                            active_req = Some(req);
                            current_response.clear();
                        } else {
                            break; // Channel closed
                        }
                    }
                    // Listen for socket responses concurrently
                    read_res = reader.read_line(&mut line_buf) => {
                        match read_res {
                            Ok(0) => {
                                warn!("ServerQuery disconnected");
                                break;
                            }
                            Ok(_) => {
                                let trimmed = line_buf.trim();
                                if trimmed.is_empty() {
                                    line_buf.clear();
                                    continue;
                                }

                                if trimmed.starts_with("notify") {
                                    // Async event (e.g. notifycliententerview)
                                    debug!("Event Received: {}", trimmed);
                                    // TODO: Forward to a broadcast channel if Dart UI needs it
                                } else if trimmed.starts_with("error") {
                                    // Command completion
                                    if let Some(req) = active_req.take() {
                                        let error_parsed = parse_response(trimmed);
                                        let mut is_error = false;
                                        
                                        if let Some(err_obj) = error_parsed.first() {
                                            if err_obj.get("id").map(|s| s.as_str()) != Some("0") {
                                                is_error = true;
                                            }
                                        }

                                        if is_error {
                                            let _ = req.response_sender.send(Err(anyhow!("Query error: {}", trimmed)));
                                        } else {
                                            let mut parsed_data = Vec::new();
                                            if trimmed == "error id=0 msg=ok" && current_response.is_empty() {
                                                let mut success = HashMap::new();
                                                success.insert("status".to_string(), "ok".to_string());
                                                parsed_data.push(success);
                                            }

                                            for resp_line in &current_response {
                                                let mut parsed = parse_response(resp_line);
                                                parsed_data.append(&mut parsed);
                                            }

                                            let _ = req.response_sender.send(Ok(parsed_data));
                                        }
                                    }
                                } else {
                                    // Data line for active command
                                    if active_req.is_some() {
                                        current_response.push(trimmed.to_string());
                                    } else {
                                        debug!("Orphaned response line: {}", trimmed);
                                    }
                                }
                                line_buf.clear();
                            }
                            Err(e) => {
                                warn!("Socket read error: {}", e);
                                break;
                            }
                        }
                    }
                }
            }
            
            // Clean up if connection loop breaks
            if let Some(req) = active_req {
                let _ = req.response_sender.send(Err(anyhow!("Connection closed while awaiting response")));
            }
        });

        // Drop the lock to allow send_command to be called for auth
        drop(client);

        if !user.is_empty() && !pass.is_empty() {
            let auth_cmd = format!("login {} {}", escape(user), escape(pass));
            let auth_res = Self::send_command(&auth_cmd).await;
            if auth_res.is_err() {
                return Err(anyhow!("Login failed: {:?}", auth_res.err().unwrap()));
            }
        }
        
        let use_res = Self::send_command("use port=9987").await;
        if use_res.is_err() {
            return Err(anyhow!("Use port failed: {:?}", use_res.err().unwrap()));
        }

        Ok("Connected".to_string())
    }

    pub async fn send_command(command: &str) -> Result<String> {
        let client = QUERY_CLIENT.lock().await;
        if let Some(tx) = &client.tx {
            let (resp_tx, resp_rx) = oneshot::channel();
            let req = Request {
                command: command.to_string(),
                response_sender: resp_tx,
            };
            
            tx.send(req).await.map_err(|_| anyhow!("Failed to send command to queue worker"))?;
            drop(client); // Important: drop lock so we don't block other commands while awaiting response
            
            match resp_rx.await {
                Ok(Ok(parsed_data)) => {
                    match serde_json::to_string(&parsed_data) {
                        Ok(json) => Ok(json),
                        Err(e) => Err(anyhow!("Failed to serialize response: {}", e)),
                    }
                }
                Ok(Err(e)) => Err(e),
                Err(_) => Err(anyhow!("Failed to receive response from queue worker")),
            }
        } else {
            Err(anyhow!("Not connected"))
        }
    }

    pub async fn disconnect() -> Result<()> {
        let mut client = QUERY_CLIENT.lock().await;
        client.tx = None; // Dropping the sender will break the loop and close the socket
        Ok(())
    }
}
