import SwiftUI
import Foundation
import AuthenticationServices

struct LoginView: View {
    @State var username = ""
    @State var password = ""
    @State private var showingLoginErrorAlert = false
    @StateObject var oauthSignInWrapper: OAuthSignInViewModel
    @EnvironmentObject var auth: Auth
    
    let apiHostname: String
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init(apiHostname: String) {
        self.apiHostname = apiHostname
        self._oauthSignInWrapper = StateObject(wrappedValue: OAuthSignInViewModel(apiHostname: apiHostname))
    }
    
    var body: some View {
        VStack {
            Text("Log In")
                .font(.largeTitle)
            TextField("Email", text: $username)
                .padding()
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(.emailAddress)
                .padding(.horizontal)
            SecureField("Password", text: $password)
                .padding()
                .padding(.horizontal)
            AsyncButton("Log In") {
                let loginData = try await login()
                try await handleLoginComplete(loginData: loginData)
            }
            .frame(width: 120.0, height: 60.0)
            .disabled(username.isEmpty || password.isEmpty)
            Spacer()
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task {
                    try await handleSIWA(result: result)
                }
            }
            .padding()
            .frame(width: 250, height: 70)
            AsyncButton(image: "sign-in-with-google") {
                let loginData = try await oauthSignInWrapper.signIn(with: .google)
                try await handleLoginComplete(loginData: loginData)
            }
            .padding()
            .frame(width: 250, height: 70)
            AsyncButton(image: "sign-in-with-github") {
                let loginData = try await oauthSignInWrapper.signIn(with: .github)
                try await handleLoginComplete(loginData: loginData)
            }
            .padding()
            .frame(width: 250, height: 70)
        }
        .alert(isPresented: $showingLoginErrorAlert) {
            Alert(title: Text("Error"), message: Text("Could not log in. Check your credentials and try again"))
        }
    }
    
    @MainActor
    func login() async throws -> LoginResultData {
        let path = "\(apiHostname)/auth/login"
        guard let url = URL(string: path) else {
            fatalError("Failed to convert URL")
        }
        guard let loginString = "\(username):\(password)".data(using: .utf8)?.base64EncodedString() else {
            fatalError("Failed to encode credentials")
        }

        var loginRequest = URLRequest(url: url)
        loginRequest.addValue("Basic \(loginString)", forHTTPHeaderField: "Authorization")
        loginRequest.httpMethod = "POST"

        do {
            let (data, response) = try await URLSession.shared.data(for: loginRequest)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw LoginError()
            }
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            return LoginResultData(apiToken: loginResponse.apiToken.value, streamToken: loginResponse.streamToken)
        } catch {
            self.showingLoginErrorAlert = true
            throw error
        }
    }
    
    @MainActor
    func handleSIWA(result: Result<ASAuthorization, Error>) async throws -> LoginResultData {
        switch result {
        case .failure(let error):
            self.showingLoginErrorAlert = true
            print("Error \(error)")
            throw error
        case .success(let authResult):
            if let credential = authResult.credential as? ASAuthorizationAppleIDCredential {
                guard
                    let identityToken = credential.identityToken,
                    let tokenString = String(data: identityToken, encoding: .utf8)
                else {
                    print("Failed to get token from credential")
                    self.showingLoginErrorAlert = true
                    throw LoginError()
                }
                let name: String?
                if let nameProvided = credential.fullName {
                    name = "\(nameProvided.givenName ?? "") \(nameProvided.familyName ?? "")"
                } else {
                    name = nil
                }
                let requestData = SignInWithAppleToken(token: tokenString, name: name, username: credential.email)
                let path = "\(apiHostname)/auth/siwa"
                guard let url = URL(string: path) else {
                    fatalError("Failed to convert URL")
                }

                do {
                    var loginRequest = URLRequest(url: url)
                    loginRequest.httpMethod = "POST"
                    loginRequest.httpBody = try JSONEncoder().encode(requestData)
                    let (data, response) = try await URLSession.shared.data(for: loginRequest)
                    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                        self.showingLoginErrorAlert = true
                        throw LoginError()
                    }
                    let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                    return LoginResultData(apiToken: loginResponse.apiToken.value, streamToken: loginResponse.streamToken)
                } catch {
                    self.showingLoginErrorAlert = true
                    throw error
                }
            } else {
                self.showingLoginErrorAlert = true
                throw LoginError()
            }
        }
    }
    
    @MainActor
    func handleLoginComplete(loginData: LoginResultData) async throws {
        do {
            let path = "\(apiHostname)/account"
            guard let url = URL(string: path) else {
                fatalError("Failed to convert URL")
            }

            var loginRequest = URLRequest(url: url)
            loginRequest.addValue("Bearer \(loginData.apiToken)", forHTTPHeaderField: "Authorization")
            loginRequest.httpMethod = "GET"
            let (data, response) = try await URLSession.shared.data(for: loginRequest)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                self.showingLoginErrorAlert = true
                throw LoginError()
            }
            let userData = try JSONDecoder().decode(UserData.self, from: data)
            appDelegate.connectUser(token: loginData.streamToken, username: userData.username, name: userData.username)
        } catch {
            self.showingLoginErrorAlert = true
            throw error
        }
        auth.token = loginData.apiToken
    }
}

struct Login_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(apiHostname: "http://localhost:8080")
    }
}
