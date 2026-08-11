//
//  AuthenticationView.swift
//  Simple Store
//
//  Created by Michael Steenkamp on 2026-08-10.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct AuthenticationView: View {
    @Environment(SessionManager.self) private var session
    
    @State private var isLoginMode = true
    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var errorMessage = ""
    @State private var isProcessing = false
    
    var isFormValid: Bool {
        if isLoginMode {
            return !email.isEmpty && password.count >= 6
        } else {
            return !email.isEmpty && password.count >= 6 && !fullName.isEmpty
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "storefront.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                            .padding(.top, 40)
                        
                        Text("Simple Store")
                            .font(.largeTitle)
                            .fontWeight(.heavy)
                        
                        Text(isLoginMode ? "Sign in to access your store" : "Create an account to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Form
                    VStack(spacing: 16) {
                        if !isLoginMode {
                            TextField("Full Name", text: $fullName)
                                .textContentType(.name)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(12)
                        }
                        
                        TextField("Email Address", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        
                        SecureField("Password (min 6 characters)", text: $password)
                            .textContentType(isLoginMode ? .password : .newPassword)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Actions
                    VStack(spacing: 16) {
                        Button(action: handleAction) {
                            HStack {
                                if isProcessing {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isLoginMode ? "Sign In" : "Create Account")
                                }
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!isFormValid || isProcessing)
                        
                        Button(action: {
                            withAnimation {
                                isLoginMode.toggle()
                                errorMessage = ""
                            }
                        }) {
                            Text(isLoginMode ? "Don't have an account? Sign up" : "Already have an account? Sign in")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    private func handleAction() {
        isProcessing = true
        errorMessage = ""
        
        Task {
            if isLoginMode {
                await loginUser()
            } else {
                await registerUser()
            }
        }
    }
    
    private func loginUser() async {
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
            await session.checkAuthenticationState()
        } catch {
            isProcessing = false
            errorMessage = error.localizedDescription
        }
    }
    
    private func registerUser() async {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid
            
            let newUser = AppUser(id: uid, email: email, role: .guest, storeId: nil, name: fullName)
            let db = Firestore.firestore()
            try await db.collection("users").document(uid).setData(try Firestore.Encoder().encode(newUser))
            
            await session.checkAuthenticationState()
        } catch {
            isProcessing = false
            errorMessage = error.localizedDescription
        }
    }
}
