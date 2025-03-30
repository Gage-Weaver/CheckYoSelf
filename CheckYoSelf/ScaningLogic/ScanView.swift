//
//  ScanView.swift
//  CheckYoSelf
//
//  Created by Carlos Mbendera on 29/03/2025.
//

import SwiftUI
import RealityKit

struct ScanView: View {
    
    @State private var session: ObjectCaptureSession?
    @State private var imageFolderPath: URL?
    @State private var photogrammetrySession: PhotogrammetrySession?
    @State private var modelFolderPath: URL?
    @State private var isProgressing = false
    @State private var quickLookIsPresented = false
    
    // Upload related states
    @State private var showUploadSheet = false
    @State private var modelName = ""
    @State private var modelDescription = ""
    @State private var isUploading = false
    @State private var showUploadSuccess = false
    @State private var showUploadError = false
    @State private var uploadError: Error?
    
    // New state to track last scan
    @State private var lastScanURL: URL?
    
    var modelPath: URL? {
        return modelFolderPath?.appending(path: "NewlyScannedModel.usdz")
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if let session {
                ObjectCaptureView(session: session)
                
                VStack(spacing: 16) {
                    if session.state == .ready || session.state == .detecting {
                        CreateButton(session: session)
                    }
                    
                    HStack {
                        Text(session.state.label)
                            .bold()
                            .foregroundStyle(.yellow)
                            .padding(.bottom)
                    }
                }
            }
            
            if isProgressing {
                LavaLamp()
                    .overlay {
                        VStack {
                            Text("Processing Scan...")
                            ProgressView()
                        }
                    }
            }
        }
        .task {
            await initializeScanSession()
        }
        .onChange(of: session?.userCompletedScanPass) { _, newValue in
            if let newValue, newValue {
                session?.finish()
            }
        }
        .onChange(of: session?.state) { _, newValue in
            if newValue == .completed {
                session = nil
                Task {
                    await startReconstruction()
                }
            }
        }
        .sheet(isPresented: $quickLookIsPresented) {
            if let modelPath {
                ARQuickLookView(
                    modelFile: modelPath,
                    endCaptureCallback: {
                        quickLookIsPresented = false
                        Task {
                            await restartScanSession()
                        }
                    },
                    onUpload: {
                        showUploadSheet = true
                    }
                )
            } else {
                Text("Model file not found")
                    .onDisappear {
                        quickLookIsPresented = false
                    }
            }
        }
        .sheet(isPresented: $showUploadSheet) {
            uploadFormSheet()
        }
        .alert("Upload Successful", isPresented: $showUploadSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your model has been uploaded successfully!")
        }
        .alert("Upload Failed", isPresented: $showUploadError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(uploadError?.localizedDescription ?? "An unknown error occurred")
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private func uploadFormSheet() -> some View {
        NavigationView {
            Form {
                Section(header: Text("Model Information")) {
                    TextField("Model Name", text: $modelName)
                    TextField("Description", text: $modelDescription)
                }
            }
            .navigationTitle("Upload Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showUploadSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isUploading {
                        ProgressView()
                    } else {
                        Button("Upload") {
                            uploadModel()
                        }
                        .disabled(modelName.isEmpty)
                    }
                }
            }
        }
    }
    
    // MARK: - Scan Session Management
    
    private func initializeScanSession() async {
        guard let directory = createNewScanDirectory() else { return }
        
        session = ObjectCaptureSession()
        modelFolderPath = directory.appending(path: "Models/")
        imageFolderPath = directory.appending(path: "Images/")
        
        guard let imageFolderPath else { return }
        session?.start(imagesDirectory: imageFolderPath)
    }
    
    private func restartScanSession() async {
        guard let directory = createNewScanDirectory() else { return }
        
        session = ObjectCaptureSession()
        modelFolderPath = directory.appending(path: "Models/")
        imageFolderPath = directory.appending(path: "Images/")
        
        guard let imageFolderPath else { return }
        session?.start(imagesDirectory: imageFolderPath)
    }
    
    // MARK: - Model Processing
    
    private func startReconstruction() async {
        guard let modelFolderURL = modelFolderPath,
              let imageFolderPath,
              let modelPath else { return }
        
        do {
            try FileManager.default.createDirectory(at: modelFolderURL, withIntermediateDirectories: true)
        } catch {
            print("Failed to create model directory: \(error)")
            return
        }
        
        isProgressing = true
        
        do {
            photogrammetrySession = try PhotogrammetrySession(input: imageFolderPath)
            guard let photogrammetrySession else { return }
            
            try photogrammetrySession.process(requests: [.modelFile(url: modelPath)])
            
            for try await output in photogrammetrySession.outputs {
                switch output {
                case .requestProgress(let request, let fractionComplete):
                    print("Progress for \(request): \(fractionComplete)")
                    
                case .requestComplete(let request, let result):
                    print("Request complete: \(request), result: \(result)")
                    if case .modelFile = request {
                        if FileManager.default.fileExists(atPath: modelPath.path) {
                            isProgressing = false
                            self.photogrammetrySession = nil
                            
                            // Save to bundle and set last scan URL
                            if let bundleURL = saveToBundle(fileURL: modelPath) {
                                lastScanURL = bundleURL
                            }
                            
                            quickLookIsPresented = true
                        } else {
                            print("Model file doesn't exist at path: \(modelPath.path)")
                        }
                    }
                    
                case .requestError, .processingCancelled:
                    isProgressing = false
                    self.photogrammetrySession = nil
                    
                case .processingComplete:
                    isProgressing = false
                    self.photogrammetrySession = nil
                    
                    // Save to bundle and set last scan URL
                  //  if let modelPath = modelPath, FileManager.default.fileExists(atPath: modelPath.path) {
                        if let bundleURL = saveToBundle(fileURL: modelPath) {
                            lastScanURL = bundleURL
                        }
                    //}
                    
                    quickLookIsPresented = true
                    
                default:
                    break
                }
            }
        } catch {
            print("Reconstruction error", error)
            isProgressing = false
        }
    }
    
    // MARK: - File Management
    
    private func saveToBundle(fileURL: URL) -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Couldn't access documents directory")
            return nil
        }
        
        let destinationURL = documentsDirectory.appendingPathComponent("LastScan.usdz")
        
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy the file
            try FileManager.default.copyItem(at: fileURL, to: destinationURL)
            print("Successfully saved scan to bundle at: \(destinationURL.path)")
            return destinationURL
        } catch {
            print("Error saving file to bundle: \(error)")
            return nil
        }
    }
    
    func createNewScanDirectory() -> URL? {
        guard let capturesFolder = getRootScansFolder() else { return nil }
        
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date())
        let newCaptureDirectory = capturesFolder.appendingPathComponent(timestamp, isDirectory: true)
        
        do {
            try FileManager.default.createDirectory(atPath: newCaptureDirectory.path, withIntermediateDirectories: true)
            return newCaptureDirectory
        } catch {
            print("Failed to create capture path: \(error)")
            return nil
        }
    }
    
    private func getRootScansFolder() -> URL? {
        guard let documentFolder = try? FileManager.default.url(for: .documentDirectory,
                                                              in: .userDomainMask,
                                                              appropriateFor: nil,
                                                              create: false) else { return nil }
        return documentFolder.appendingPathComponent("Scans/", isDirectory: true)
    }
    
    // MARK: - Upload Functionality
    
    private func uploadModel() {
        guard let modelPath = modelPath else { return }
        
        isUploading = true
        
        Task {
            do {
                try await uploadUSDZModel(
                    from: modelPath,
                    customName: modelName.isEmpty ? "MyModel" : modelName,
                    description: modelDescription
                )
                
                DispatchQueue.main.async {
                    isUploading = false
                    showUploadSheet = false
                    showUploadSuccess = true
                    // Reset form for next upload
                    modelName = ""
                    modelDescription = ""
                }
            } catch {
                DispatchQueue.main.async {
                    isUploading = false
                    uploadError = error
                    showUploadError = true
                }
            }
        }
    }
    
    private func uploadUSDZModel(from fileURL: URL, customName: String, description: String) async throws {
        guard let url = URL(string: "https://uploads.pinata.cloud/v3/files") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer YOUR_API_TOKEN_HERE", forHTTPHeaderField: "Authorization")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        do {
            let fileData = try Data(contentsOf: fileURL)
            
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
            body.append("Content-Type: model/vnd.usdz+zip\r\n\r\n")
            body.append(fileData)
            body.append("\r\n")
            
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"network\"\r\n\r\n")
            body.append("public")
            body.append("\r\n")
            
            if !customName.isEmpty {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n")
                body.append(customName.hasSuffix(".usdz") ? customName : "\(customName).usdz")
                body.append("\r\n")
            }
            
            if !description.isEmpty {
                body.append("--\(boundary)\r\n")
                body.append("Content-Disposition: form-data; name=\"description\"\r\n\r\n")
                body.append(description)
                body.append("\r\n")
            }
            
            body.append("--\(boundary)--\r\n")
            request.httpBody = body
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Status code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let responseString = String(data: responseData, encoding: .utf8) {
                        print("Response: \(responseString)")
                    }
                    throw NSError(domain: "PinataUpload", code: httpResponse.statusCode,
                                userInfo: [NSLocalizedDescriptionKey: "Upload failed with status \(httpResponse.statusCode)"])
                }
            }
        } catch {
            print("Upload error: \(error)")
            throw error
        }
    }
}
