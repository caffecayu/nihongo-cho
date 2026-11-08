// Windows desktop shell for 毎日にほんご帳: shows the bundled web app (docs/) in a native window.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("failed to start 毎日にほんご帳");
}
