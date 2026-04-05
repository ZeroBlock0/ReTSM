# ReTSM

ReTeamSpeakManager

## Prerequisites

Ensure you have the following installed:
1. [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.22+ recommended)
2. [Rust](https://www.rust-lang.org/tools/install)
3. `flutter_rust_bridge_codegen` installed globally:
   ```bash
   cargo install 'flutter_rust_bridge_codegen@^2.0.0'
   ```

## Setup

Since this project uses `flutter_rust_bridge` to connect Dart UI with Rust backend logic, you need to run the code generator before compiling.

1. Install Dart dependencies:
   ```bash
   flutter pub get
   ```

2. Generate the Rust-Dart bridge bindings:
   ```bash
   flutter_rust_bridge_codegen generate
   ```

3. Run the application (Desktop):
   ```bash
   flutter run -d windows # Or macos/linux
   ```
