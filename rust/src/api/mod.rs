#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Initialize our custom tracing layer
    crate::logger::init_logger();
}


pub fn greet() -> String {
    "Hello from Rust!".to_string()
}

pub fn get_config_from_rust() -> String {
    match super::config::load_config() {
        Ok(c) => format!("{:?}", c),
        Err(e) => format!("Error loading config: {}", e),
    }
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
            let _ = sink.add(msg);
        }
    });

    // Run the actual connection
    tokio::spawn(async move {
        if let Err(e) = crate::ts_client::TsClient::connect_and_listen(ip, port, api_key, tx).await {
            tracing::error!("TeamSpeak client error: {:?}", e);
        }
    });

    Ok(())
}

pub async fn send_ts_message(payload: String) -> anyhow::Result<()> {
    crate::ts_client::TsClient::send_message(payload).await
}

pub async fn request_ts_api_key(ip: String, port: u16) -> anyhow::Result<String> {
    crate::ts_client::TsClient::request_api_key(ip, port).await
}

// ServerQuery bindings
pub async fn connect_query(ip: String, port: u16, user: String, pass: String) -> anyhow::Result<String> {
    crate::query_client::QueryClient::connect(&ip, port, &user, &pass).await
}

pub async fn query_send_command(command: String) -> anyhow::Result<String> {
    crate::query_client::QueryClient::send_command(&command).await
}

pub async fn query_disconnect() -> anyhow::Result<()> {
    crate::query_client::QueryClient::disconnect().await
}

// Debug Log bindings
pub fn toggle_rust_debug_log(enabled: bool, path: String) {
    crate::logger::toggle_debug_log(enabled, path);
}
