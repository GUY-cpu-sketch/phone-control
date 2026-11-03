import SwiftUI
import WebKit

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct ContentView: View {
    @EnvironmentObject private var session: RemoteSession
    @State private var serverURL = "wss://YOUR-RENDER-SERVICE.onrender.com/ws"
    @State private var urlText = "https://www.google.com"
    @State private var showSettings = false
    @State private var keepScreenOn = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Button { session.browser.goBack() } label: { Image(systemName: "chevron.left") }
                        .disabled(!session.browser.canGoBack)
                    Button { session.browser.goForward() } label: { Image(systemName: "chevron.right") }
                        .disabled(!session.browser.canGoForward)
                    TextField("Address", text: $urlText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { session.browser.navigate(urlText) }
                    Button { session.browser.reload() } label: { Image(systemName: "arrow.clockwise") }
                }
                .padding(8)

                WebViewContainer(webView: session.browser.webView)
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("Phone Browser")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .sheet(isPresented: $showSettings) { settings }
            .onAppear { urlText = session.browser.currentURL; UIApplication.shared.isIdleTimerDisabled = keepScreenOn }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
            .onChange(of: session.browser.currentURL) { _, value in urlText = value }
        }
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section("Render server") {
                    TextField("wss://…/ws", text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    HStack {
                        Circle().fill(session.isConnected ? .green : .red).frame(width: 10, height: 10)
                        Text(session.statusText)
                    }
                    Button(session.isConnected ? "Disconnect" : "Connect") {
                        if session.isConnected { session.disconnect() }
                        else { session.connect(to: serverURL) }
                    }
                    if let code = session.pairingCode {
                        VStack(alignment: .leading) {
                            Text("Pairing code").font(.caption).foregroundStyle(.secondary)
                            Text(code).font(.system(size: 34, weight: .bold, design: .monospaced))
                        }
                    }
                    if let error = session.lastError { Text(error).foregroundStyle(.red) }
                }
                Section("Display") {
                    Toggle("Keep iPhone screen awake", isOn: $keepScreenOn)
                        .onChange(of: keepScreenOn) { _, value in UIApplication.shared.isIdleTimerDisabled = value }
                    Text("When enabled, the iPhone will not auto-lock while Phone Browser is open.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Remote control") {
                    Text("The Chromebook website controls this browser app only. It can navigate, go back/forward, reload, scroll, tap webpage elements, and type into the focused webpage field.")
                }
            }
            .navigationTitle("Remote Access")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showSettings = false } } }
        }
    }
}
