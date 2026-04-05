use chrono::Local;
use std::fs::{File, OpenOptions};
use std::io::Write;
use std::sync::{Arc, Mutex};
use tracing::{Event, Subscriber};
use tracing_subscriber::fmt::format::Writer;
use tracing_subscriber::registry::LookupSpan;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter, Layer};

lazy_static::lazy_static! {
    pub static ref DEBUG_FILE: Arc<Mutex<Option<File>>> = Arc::new(Mutex::new(None));
}

pub fn init_logger() {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));

    // Console layer
    let fmt_layer = tracing_subscriber::fmt::layer()
        .with_target(true)
        .with_thread_ids(false)
        .with_level(true);

    // Custom File layer
    let file_layer = FileLayer;

    let subscriber = tracing_subscriber::registry()
        .with(filter)
        .with(fmt_layer)
        .with(file_layer);

    let _ = subscriber.try_init();
}

pub fn toggle_debug_log(enabled: bool, path: String) {
    let mut file_opt = DEBUG_FILE.lock().unwrap();
    if enabled {
        if file_opt.is_none() {
            if let Ok(file) = OpenOptions::new().create(true).append(true).open(&path) {
                *file_opt = Some(file);
                tracing::info!("Debug log started to file: {}", path);
            }
        }
    } else {
        if file_opt.is_some() {
            tracing::info!("Debug log stopped.");
            *file_opt = None;
        }
    }
}

struct FileLayer;

impl<S: Subscriber + for<'a> LookupSpan<'a>> Layer<S> for FileLayer {
    fn on_event(&self, event: &Event<'_>, _ctx: tracing_subscriber::layer::Context<'_, S>) {
        if let Ok(mut file_opt) = DEBUG_FILE.lock() {
            if let Some(file) = file_opt.as_mut() {
                let mut buf = String::new();
                let meta = event.metadata();

                // Extremely simple formatting for the file
                let timestamp = Local::now().format("%Y-%m-%d %H:%M:%S%.3f");
                buf.push_str(&format!(
                    "[{}] {} [{}] ",
                    timestamp,
                    meta.level(),
                    meta.target()
                ));

                let mut visitor = StringVisitor(&mut buf);
                event.record(&mut visitor);

                buf.push('\n');
                let _ = file.write_all(buf.as_bytes());
                let _ = file.flush();
            }
        }
    }
}

struct StringVisitor<'a>(&'a mut String);

impl<'a> tracing::field::Visit for StringVisitor<'a> {
    fn record_debug(&mut self, field: &tracing::field::Field, value: &dyn std::fmt::Debug) {
        if field.name() == "message" {
            self.0.push_str(&format!("{:?} ", value));
        } else {
            self.0.push_str(&format!("{}={:?} ", field.name(), value));
        }
    }
}
