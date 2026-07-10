use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::Duration;

use anyhow::{anyhow, Context, Result};
use futures_util::{SinkExt, StreamExt};
use serde::Serialize;
use tokio::sync::{mpsc, watch, Mutex};
use tokio::time::{sleep_until, timeout, Instant};
use tokio_tungstenite::tungstenite::client::IntoClientRequest;
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message};
use tracing::{debug, info};

const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);
const AUTH_TIMEOUT: Duration = Duration::from_secs(15);
const OUTBOUND_QUEUE_TIMEOUT: Duration = Duration::from_secs(5);

struct TsConnection {
    id: u64,
    sender: mpsc::Sender<String>,
    shutdown: watch::Sender<bool>,
}

lazy_static::lazy_static! {
    static ref TS_CONNECTION: Arc<Mutex<Option<TsConnection>>> = Arc::new(Mutex::new(None));
}

static NEXT_CONNECTION_ID: AtomicU64 = AtomicU64::new(1);

#[derive(Debug, PartialEq, Eq)]
enum AuthState {
    Pending,
    Authorized,
    Rejected(String),
}

#[derive(Serialize)]
struct AuthPayload<'a> {
    identifier: &'a str,
    version: &'a str,
    name: &'a str,
    description: &'a str,
    content: AuthContent<'a>,
}

#[derive(Serialize)]
struct AuthContent<'a> {
    #[serde(rename = "apiKey")]
    api_key: &'a str,
}

#[derive(Serialize)]
struct TsMessage<'a> {
    #[serde(rename = "type")]
    msg_type: &'a str,
    payload: AuthPayload<'a>,
}

pub struct TsClient;

impl TsClient {
    pub async fn connect_and_listen(
        ip: String,
        port: u16,
        api_key: String,
        event_sender: mpsc::Sender<String>,
    ) -> Result<()> {
        Self::disconnect().await;

        let uri = format!("ws://{ip}:{port}");
        info!("Connecting to TeamSpeak Remote Apps at {uri}");

        let mut request = uri.into_client_request()?;
        request.headers_mut().insert(
            "Origin",
            tokio_tungstenite::tungstenite::http::HeaderValue::from_static("http://localhost"),
        );
        let (ws_stream, _) = timeout(CONNECT_TIMEOUT, connect_async(request))
            .await
            .context("Timed out while connecting to TeamSpeak Remote Apps")?
            .context("Failed to connect to TeamSpeak Remote Apps")?;
        let (mut write, mut read) = ws_stream.split();

        let (out_tx, mut out_rx) = mpsc::channel::<String>(100);
        let (shutdown_tx, mut shutdown_rx) = watch::channel(false);
        let connection_id = NEXT_CONNECTION_ID.fetch_add(1, Ordering::Relaxed);

        {
            let mut connection = TS_CONNECTION.lock().await;
            *connection = Some(TsConnection {
                id: connection_id,
                sender: out_tx.clone(),
                shutdown: shutdown_tx,
            });
        }

        let auth_request = TsMessage {
            msg_type: "auth",
            payload: AuthPayload {
                identifier: "com.retsm.app",
                version: "1.0.0",
                name: "ReTSM",
                description: "ReTSM Dashboard",
                content: AuthContent { api_key: &api_key },
            },
        };
        let auth_message = serde_json::to_string(&auth_request)?;
        write
            .send(Message::Text(auth_message))
            .await
            .context("Failed to send TeamSpeak authorization request")?;

        let auth_deadline = Instant::now() + AUTH_TIMEOUT;
        let mut authorized = false;
        let result = loop {
            tokio::select! {
                changed = shutdown_rx.changed() => {
                    if changed.is_err() || *shutdown_rx.borrow() {
                        break Ok(());
                    }
                }
                _ = sleep_until(auth_deadline), if !authorized => {
                    break Err(anyhow!("Timed out while waiting for TeamSpeak Remote Apps authorization"));
                }
                outbound = out_rx.recv() => {
                    match outbound {
                        Some(message) => {
                            debug!("Sending TeamSpeak Remote Apps message ({} bytes)", message.len());
                            if let Err(error) = write.send(Message::Text(message)).await {
                                break Err(anyhow!("Failed to send TeamSpeak Remote Apps message: {error}"));
                            }
                        }
                        None => break Ok(()),
                    }
                }
                incoming = read.next() => {
                    match incoming {
                        Some(Ok(Message::Text(text))) => {
                            match auth_state(&text) {
                                AuthState::Authorized if !authorized => {
                                    authorized = true;
                                    let connected_event = serde_json::json!({
                                        "type": "connection",
                                        "status": "authorized",
                                    });
                                    if event_sender.send(connected_event.to_string()).await.is_err() {
                                        break Ok(());
                                    }
                                }
                                AuthState::Rejected(message) => {
                                    break Err(anyhow!("TeamSpeak Remote Apps authorization rejected: {message}"));
                                }
                                AuthState::Pending | AuthState::Authorized => {}
                            }

                            if event_sender.send(text.to_string()).await.is_err() {
                                break Ok(());
                            }
                        }
                        Some(Ok(Message::Ping(payload))) => {
                            if let Err(error) = write.send(Message::Pong(payload)).await {
                                break Err(anyhow!("Failed to respond to TeamSpeak Remote Apps ping: {error}"));
                            }
                        }
                        Some(Ok(Message::Close(_))) | None => break Ok(()),
                        Some(Ok(_)) => {}
                        Some(Err(error)) => break Err(anyhow!("TeamSpeak Remote Apps WebSocket error: {error}")),
                    }
                }
            }
        };

        Self::clear_connection(connection_id).await;
        result
    }

    pub async fn request_api_key(ip: String, port: u16) -> Result<String> {
        let uri = format!("ws://{ip}:{port}");
        info!("Requesting TeamSpeak Remote Apps authorization at {uri}");

        let mut request = uri.into_client_request()?;
        request.headers_mut().insert(
            "Origin",
            tokio_tungstenite::tungstenite::http::HeaderValue::from_static("http://localhost"),
        );
        let (ws_stream, _) = timeout(CONNECT_TIMEOUT, connect_async(request))
            .await
            .context("Timed out while connecting to TeamSpeak Remote Apps")?
            .context("Failed to connect to TeamSpeak Remote Apps")?;
        let (mut write, mut read) = ws_stream.split();

        let auth_request = TsMessage {
            msg_type: "auth",
            payload: AuthPayload {
                identifier: "com.retsm.app",
                version: "1.0.0",
                name: "ReTSM",
                description: "ReTSM Dashboard",
                content: AuthContent { api_key: "" },
            },
        };
        write
            .send(Message::Text(serde_json::to_string(&auth_request)?))
            .await
            .context("Failed to request TeamSpeak Remote Apps authorization")?;

        timeout(AUTH_TIMEOUT, async {
            while let Some(incoming) = read.next().await {
                match incoming? {
                    Message::Text(text) => {
                        let payload: serde_json::Value = serde_json::from_str(&text)
                            .context("Received malformed TeamSpeak authorization response")?;
                        if payload["type"] == "auth" {
                            if let Some(api_key) = auth_api_key(&payload) {
                                return Ok(api_key.to_string());
                            }
                            if let AuthState::Rejected(message) = auth_state(&text) {
                                return Err(anyhow!(
                                    "TeamSpeak Remote Apps authorization rejected: {message}"
                                ));
                            }
                        } else if payload["type"] == "error" {
                            let message = payload["message"]
                                .as_str()
                                .or_else(|| payload["payload"]["message"].as_str())
                                .unwrap_or("Unknown Remote Apps error");
                            return Err(anyhow!("TeamSpeak Remote Apps error: {message}"));
                        }
                    }
                    Message::Ping(payload) => write.send(Message::Pong(payload)).await?,
                    Message::Close(_) => {
                        return Err(anyhow!(
                            "TeamSpeak Remote Apps closed before authorization completed"
                        ))
                    }
                    _ => {}
                }
            }
            Err(anyhow!(
                "TeamSpeak Remote Apps closed before authorization completed"
            ))
        })
        .await
        .context("Timed out while waiting for TeamSpeak Remote Apps authorization")?
    }

    pub async fn send_message(message: String) -> Result<()> {
        let sender = {
            let connection = TS_CONNECTION.lock().await;
            connection.as_ref().map(|current| current.sender.clone())
        }
        .ok_or_else(|| anyhow!("Not connected to TeamSpeak Remote Apps"))?;

        timeout(OUTBOUND_QUEUE_TIMEOUT, sender.send(message))
            .await
            .context("Timed out while queuing TeamSpeak Remote Apps message")?
            .map_err(|_| anyhow!("TeamSpeak Remote Apps connection is closed"))
    }

    pub async fn disconnect() {
        let connection = {
            let mut current = TS_CONNECTION.lock().await;
            current.take()
        };

        if let Some(connection) = connection {
            let _ = connection.shutdown.send(true);
        }
    }

    async fn clear_connection(connection_id: u64) {
        let mut connection = TS_CONNECTION.lock().await;
        if connection
            .as_ref()
            .is_some_and(|current| current.id == connection_id)
        {
            *connection = None;
        }
    }
}

fn auth_api_key(payload: &serde_json::Value) -> Option<&str> {
    payload["payload"]["apiKey"]
        .as_str()
        .or_else(|| payload["payload"]["content"]["apiKey"].as_str())
        .filter(|api_key| !api_key.is_empty())
}

fn auth_state(text: &str) -> AuthState {
    let Ok(payload) = serde_json::from_str::<serde_json::Value>(text) else {
        return AuthState::Pending;
    };
    if payload["type"] != "auth" {
        return AuthState::Pending;
    }
    if auth_api_key(&payload).is_some()
        || payload["payload"]["success"].as_bool() == Some(true)
        || matches!(
            payload["payload"]["status"]
                .as_str()
                .map(str::to_ascii_lowercase)
                .as_deref(),
            Some("ok" | "success" | "authorized" | "approved" | "authenticated")
        )
    {
        return AuthState::Authorized;
    }

    let message = payload["payload"]["message"]
        .as_str()
        .or_else(|| payload["message"].as_str());
    if let Some(message) = message {
        let normalized = message.to_ascii_lowercase();
        if [
            "deny", "denied", "reject", "rejected", "fail", "failed", "invalid", "expired",
        ]
        .iter()
        .any(|needle| normalized.contains(needle))
        {
            return AuthState::Rejected(message.to_string());
        }
    }

    AuthState::Pending
}

#[cfg(test)]
mod tests {
    use super::{auth_state, AuthState};

    #[test]
    fn recognizes_authorized_auth_response() {
        assert_eq!(
            auth_state(r#"{"type":"auth","payload":{"apiKey":"key"}}"#),
            AuthState::Authorized,
        );
    }

    #[test]
    fn recognizes_rejected_auth_response() {
        assert_eq!(
            auth_state(r#"{"type":"auth","payload":{"message":"Authorization denied"}}"#),
            AuthState::Rejected("Authorization denied".to_string()),
        );
    }

    #[test]
    fn keeps_unconfirmed_auth_pending() {
        assert_eq!(
            auth_state(r#"{"type":"auth","payload":{"message":"User action required"}}"#),
            AuthState::Pending,
        );
    }
}
