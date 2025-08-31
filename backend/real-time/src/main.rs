use axum::routing::get;
// use axum::Server;
use serde::{Deserialize, Serialize};
use socketioxide::{
    // extract::{AckSender, Data, SocketRef},
    extract::{Data, SocketRef},
    SocketIo,
};
use tracing::info;
// use tracing_subscriber::FmtSubscriber;

// Struct matches the one from the Go service.
// TODO: Implement the missing fields and methods. Just a placeholder for now.
#[derive(Debug, Serialize, Deserialize)]
struct User {
    id: u32,
    name: String,
}

// The backend service URL
const GO_BACKEND_URL: &str = "http://localhost:8080";

// Handler for incoming socket connections
fn on_connect(socket: SocketRef) {
    info!("Socket connected: {}", socket.id);

    // Register a handler for the "get_user" event
    socket.on(
        "get_user",
        async move |socket: SocketRef, Data::<String>(user_id)| {
            info!("Received get_user request for user ID: {}", user_id);

            // 1. Create a HTTP client
            let client = reqwest::Client::new();
            let url = format!("{}/users/{}", GO_BACKEND_URL, user_id);

            // 2. Make the HTTP request to the Go backend service
            match client.get(&url).send().await {
                Ok(response) => {
                    // 3. Check if the backend responded successfully
                    if response.status().is_success() {
                        // Attempts to parse the JSON response into our User struct
                        match response.json::<User>().await {
                            Ok(user) => {
                                // 4. If successful, emit the data back to the client
                                info!("User data received: {:?}", user);

                                if let Err(e) = socket.emit("user_data", &user) {
                                    info!("Error sending user_data: {:?}", e);
                                }
                            }
                            Err(e) => {
                                info!("Failed to parse JSON from the backend: {:?}", e);

                                // Informs the client of the error
                                if let Err(e) = socket.emit(
                                    "request_error",
                                    "Failed to parse the backend JSON response.",
                                ) {
                                    info!("Error sending request_error: {:?}", e);
                                }
                            }
                        }
                    } else {
                        // The backend returned a non-2xx status error (e.g., 404 Not Found)
                        let status = response.status();
                        info!("Backend returned an error status: {}", status);

                        // Informs the client of the error
                        if let Err(e) =
                            socket.emit("request_error", &format!("Backend error: {}", status))
                        {
                            info!("Error sending request_error: {:?}", e);
                        }
                    }
                }
                Err(e) => {
                    // The request to the backend failed entirely (e.g., network error)
                    info!("Failed to contact backend service: {:?}", e);

                    // Inform the client of the error
                    if let Err(e) =
                        socket.emit("request_error", "Could not reach the backend service.")
                    {
                        info!("Error sending request_error: {:?}", e);
                    }
                }
            }
        },
    );
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::FmtSubscriber::builder()
        .with_max_level(tracing::Level::INFO)
        .init();

    // Create the SocketIO layer
    let (layer, io) = SocketIo::new_layer();

    // Register the connection handler
    io.ns("/", on_connect);

    // Create the Axum web app and apply the SocketIO layer
    let app = axum::Router::new()
        .route("/", get(|| async { "Hello from Rust Gateway!" }))
        .layer(layer);

    info!("Starting server on 127.0.0.1:3000");

    let listener = tokio::net::TcpListener::bind("127.0.0.1:3000").await?;
    let server = axum::serve(listener, app.into_make_service());

    server.await?;

    Ok(())
}
