use tokio_tungstenite::tungstenite::client::IntoClientRequest;
use anyhow::{Result, Context, anyhow};
use futures_util::{SinkExt, StreamExt};
use serde::Serialize;
use tokio::sync::{mpsc, Mutex};
use tokio_tungstenite::{connect_async, tungstenite::protocol::Message};
use tracing::{info, error, debug};
use std::sync::Arc;

lazy_static::lazy_static! {
    pub static ref TS_WRITER: Arc<Mutex<Option<mpsc::Sender<String>>>> = Arc::new(Mutex::new(None));
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
        let uri = format!("ws://{}:{}", ip, port);
        info!("Connecting to Remote Apps at {}", uri);
        
        let mut req = uri.into_client_request()?;
        req.headers_mut().insert(
            "Origin",
            tokio_tungstenite::tungstenite::http::HeaderValue::from_static("http://localhost"),
        );
        let (ws_stream, _) = connect_async(req).await.context("Failed to connect to TS WebSocket")?;
        let (mut write, mut read) = ws_stream.split();

        // Create a channel for sending messages outwards
        let (out_tx, mut out_rx) = mpsc::channel::<String>(100);
        
        // Store the sender globally
        {
            let mut writer_guard = TS_WRITER.lock().await;
            *writer_guard = Some(out_tx.clone());
        }

        // Spawn a task to handle outgoing messages
        tokio::spawn(async move {
            while let Some(msg) = out_rx.recv().await {
                debug!("Sending TS message: {}", msg);
                if let Err(e) = write.send(Message::Text(msg)).await {
                    error!("Error sending to TS WebSocket: {}", e);
                    break;
                }
            }
        });

        // Construct Auth message
        let auth_req = TsMessage {
            msg_type: "auth",
            payload: AuthPayload {
                identifier: "com.retsm.app",
                version: "1.0.0",
                name: "ReTSM",
                description: "ReTSM Dashboard",
                content: AuthContent { api_key: &api_key },
            }
        };
        
        let auth_msg = serde_json::to_string(&auth_req)?;
        out_tx.send(auth_msg).await.map_err(|e| anyhow!("Failed to send auth: {}", e))?;
        
        info!("Auth request sent");

        // Listen for incoming messages
        while let Some(msg) = read.next().await {
            match msg {
                Ok(Message::Text(text)) => {
                    let text_str = text.to_string();
                    if let Err(e) = event_sender.send(text_str).await {
                        error!("Failed to send event to Flutter channel: {}", e);
                        break; // Channel closed, probably Flutter app shutting down
                    }
                }
                Ok(Message::Close(_)) => {
                    info!("WebSocket connection closed by server");
                    break;
                }
                Err(e) => {
                    error!("WebSocket error: {}", e);
                    break;
                }
                _ => {} // Ignore ping/pong/binary
            }
        }
        
        Ok(())
    }

    pub async fn request_api_key(ip: String, port: u16) -> Result<String> {
        let uri = format!("ws://{}:{}", ip, port);
        info!("Requesting Auth API Key from {}", uri);
        
        let mut req = uri.into_client_request()?;
        req.headers_mut().insert(
            "Origin",
            tokio_tungstenite::tungstenite::http::HeaderValue::from_static("http://localhost"),
        );
        let (ws_stream, _) = connect_async(req).await.context("Failed to connect to TS WebSocket")?;
        let (mut write, mut read) = ws_stream.split();

        let auth_req = TsMessage {
            msg_type: "auth",
            payload: AuthPayload {
                identifier: "com.retsm.app",
                version: "1.0.0",
                name: "ReTSM",
                description: "ReTSM Dashboard",
                content: AuthContent { api_key: "" },
            }
        };

        let auth_msg = serde_json::to_string(&auth_req)?;
        write.send(Message::Text(auth_msg)).await?;

        while let Some(msg) = read.next().await {
            if let Ok(Message::Text(text)) = msg {
                let text_str = text.to_string();
                let v: serde_json::Value = serde_json::from_str(&text_str)?;
                if v["type"] == "auth" {
                    if let Some(key) = v["payload"]["apiKey"].as_str().or_else(|| v["payload"]["content"]["apiKey"].as_str()) {
                        if !key.is_empty() {
                            return Ok(key.to_string());
                        }
                    }
                    if let Some(msg) = v["payload"]["message"].as_str() {
                        info!("Auth status: {}", msg);
                        let lower_msg = msg.to_lowercase();
                        if lower_msg.contains("denied") || lower_msg.contains("reject") || lower_msg.contains("fail") {
                            return Err(anyhow!("Auth denied: {}", msg));
                        }
                        // Otherwise, we just keep waiting (e.g. "User action required")
                    }
                } else if v["type"] == "error" {
                     if let Some(msg) = v["payload"]["message"].as_str() {
                        return Err(anyhow!("Error from Remote App: {}", msg));
                     }
                     return Err(anyhow!("Received error from Remote App"));
                }
            } else if let Ok(Message::Close(_)) = msg {
                return Err(anyhow!("Connection closed by Remote App before receiving API key. Did you deny it?"));
            }
        }
        
        Err(anyhow!("Connection closed before receiving API key"))
    }

    pub async fn send_message(msg: String) -> Result<()> {
        let guard = TS_WRITER.lock().await;
        if let Some(tx) = &*guard {
            tx.send(msg).await.map_err(|e| anyhow!("Failed to send message: {}", e))?;
            Ok(())
        } else {
            Err(anyhow!("Not connected to Remote Apps"))
        }
    }
}