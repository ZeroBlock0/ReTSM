#[allow(unexpected_cfgs)]
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Initialize our custom tracing layer
    crate::logger::init_logger();
}

pub fn greet() -> String {
    "Hello from Rust!".to_string()
}

pub async fn start_ts_connection(
    ip: String,
    port: u16,
    api_key: String,
    sink: crate::frb_generated::StreamSink<String>,
) -> anyhow::Result<()> {
    let (tx, mut rx) = tokio::sync::mpsc::channel(100);

    // Forward messages from our internal tokio channel to the Dart StreamSink
    tokio::spawn(async move {
        while let Some(msg) = rx.recv().await {
            if sink.add(msg).is_err() {
                break;
            }
        }
    });

    // Run the actual connection
    tokio::spawn(async move {
        let error_sender = tx.clone();
        if let Err(e) = crate::ts_client::TsClient::connect_and_listen(ip, port, api_key, tx).await
        {
            tracing::error!("TeamSpeak client error: {:?}", e);
            let event = serde_json::json!({
                "type": "error",
                "message": e.to_string(),
            });
            let _ = error_sender.send(event.to_string()).await;
        }
    });

    Ok(())
}

pub async fn send_ts_message(payload: String) -> anyhow::Result<()> {
    crate::ts_client::TsClient::send_message(payload).await
}

pub async fn disconnect_ts() -> anyhow::Result<()> {
    crate::ts_client::TsClient::disconnect().await;
    Ok(())
}

pub async fn request_ts_api_key(ip: String, port: u16) -> anyhow::Result<String> {
    crate::ts_client::TsClient::request_api_key(ip, port).await
}

// ServerQuery bindings
pub async fn connect_query(
    ip: String,
    port: u16,
    virtual_server_port: u16,
    user: String,
    pass: String,
) -> anyhow::Result<String> {
    crate::query_client::QueryClient::connect(&ip, port, virtual_server_port, &user, &pass).await
}

pub async fn query_send_command(command: String) -> anyhow::Result<String> {
    crate::query_client::QueryClient::send_command(&command).await
}

#[derive(Clone, Debug)]
pub struct TsUser {
    pub client_id: i64,
    pub client_database_id: i64,
    pub client_nickname: String,
    pub cid: i64,
    pub client_type: i64,
}

pub async fn query_get_users() -> anyhow::Result<Vec<TsUser>> {
    let clients = crate::query_client::QueryClient::send_command_parsed(
        "clientlist -uid -country -ip -groups",
    )
    .await?;

    Ok(clients
        .into_iter()
        .map(|client| TsUser {
            client_id: client
                .get("clid")
                .and_then(|value| value.parse().ok())
                .unwrap_or_default(),
            client_database_id: client
                .get("client_database_id")
                .and_then(|value| value.parse().ok())
                .unwrap_or_default(),
            client_nickname: client.get("client_nickname").cloned().unwrap_or_default(),
            cid: client
                .get("cid")
                .and_then(|value| value.parse().ok())
                .unwrap_or_default(),
            client_type: client
                .get("client_type")
                .and_then(|value| value.parse().ok())
                .unwrap_or_default(),
        })
        .collect())
}

pub async fn query_disconnect() -> anyhow::Result<()> {
    crate::query_client::QueryClient::disconnect().await;
    Ok(())
}

pub async fn query_is_connected() -> bool {
    crate::query_client::QueryClient::is_connected().await
}

// Debug Log bindings
pub fn toggle_rust_debug_log(enabled: bool, path: String) {
    crate::logger::toggle_debug_log(enabled, path);
}
