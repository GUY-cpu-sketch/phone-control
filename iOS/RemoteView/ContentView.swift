import SwiftUI
import WebKit
import UIKit

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct ContentView: View {
    @EnvironmentObject private var session: RemoteSession
    @AppStorage("renderServerURL") private var serverURL = "wss://YOUR-RENDER-SERVICE.onrender.com/ws"
    @AppStorage("keepScreenOn") private var keepScreenOn = true
    @State private var urlText = "https://www.google.com"
    @State private var showSettings = false
    @State private var showConnection = false

    private var connectionColor: Color {
        session.isConnected ? .green : .secondary
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    browserBar
                    WebViewContainer(webView: session.browser.webView)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showConnection = true
                    } label: {
                        HStack(spacing: 7) {
                            Circle().fill(connectionColor).frame(width: 8, height: 8)
                            Text(session.isConnected ? "Connected" : "Remote")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .accessibilityLabel(session.isConnected ? "Connected to remote server" : "Remote connection settings")
                }
                ToolbarItem(placement: .principal) {
                    Text("Phone Browser")
                        .font(.headline.weight(.bold))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { session.browser.reload() } label: { Label("Reload page", systemImage: "arrow.clockwise") }
                        Button { showConnection = true } label: { Label("Remote connection", systemImage: "dot.radiowaves.left.and.right") }
                        Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showConnection) { connectionSheet }
            .sheet(isPresented: $showSettings) { settings }
            .onAppear {
                urlText = session.browser.currentURL
                UIApplication.shared.isIdleTimerDisabled = keepScreenOn
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
            .onChange(of: session.browser.currentURL) { _, value in
                urlText = value
            }
            .onChange(of: keepScreenOn) { _, value in
                UIApplication.shared.isIdleTimerDisabled = value
            }
        }
    }

    private var browserBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button { session.browser.goBack() } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!session.browser.canGoBack)

                Button { session.browser.goForward() } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!session.browser.canGoForward)

                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.green)

                    TextField("Search or enter website", text: $urlText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit { session.browser.navigate(urlText) }
                        .font(.subheadline)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())

                Button { session.browser.reload() } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }

            if let error = session.lastError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                        .lineLimit(1)
                    Spacer()
                    Button("Dismiss") { /* next state update will clear it */ }
                }
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.horizontal, 14)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private var connectionSheet: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: session.isConnected ? "checkmark.circle.fill" : "dot.radiowaves.left.and.right")
                            .font(.title2)
                            .foregroundStyle(session.isConnected ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.isConnected ? "iPhone is online" : "Ready to connect")
                                .font(.headline)
                            Text(session.statusText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Render WebSocket") {
                    TextField("wss://your-service.onrender.com/ws", text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Button(session.isConnected ? "Disconnect" : "Connect") {
                        if session.isConnected {
                            session.disconnect()
                        } else {
                            session.connect(to: serverURL)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                }

                if let code = session.pairingCode {
                    Section("Chromebook pairing code") {
                        HStack {
                            Spacer()
                            Text(code)
                                .font(.system(size: 42, weight: .bold, design: .monospaced))
                                .tracking(5)
                            Spacer()
                        }
                        Text("Open your Render website on the Chromebook and enter this code.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .navigationTitle("Remote Access")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showConnection = false }
                }
            }
        }
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    Toggle("Keep screen awake", isOn: $keepScreenOn)
                    Text("Prevents auto-lock while Phone Browser is open. Connect the iPhone to power for long sessions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Browser") {
                    Button("Open Google") { session.browser.navigate("https://www.google.com") }
                    Button("Reload current page") { session.browser.reload() }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.1")
                    LabeledContent("Browser engine", value: "WebKit")
                    LabeledContent("Remote transport", value: "WebSocket")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showSettings = false }
                }
            }
        }
    }
}
