//
//  ContentView.swift
//  CheckYoSelf
//
//  Created by Carlos Mbendera on 29/03/2025.
//

import SwiftUI
import QuickLookThumbnailing

// MARK: - Models

struct QuickLookItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct InventoryItem: Identifiable {
    let id: String
    let name: String
    let cid: String
    let createdAt: String
}

// MARK: - Thumbnail View for USDZ Files

struct USDZThumbnailView: View {
    let cid: String
    let fileName: String
    @State private var thumbnailImage: UIImage? = nil

    var body: some View {
        Group {
            if let thumbnailImage = thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .onAppear { generateThumbnail() }
            }
        }
        .frame(width: 100, height: 100)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    func generateThumbnail() {
        guard let url = URL(string: "https://gateway.pinata.cloud/ipfs/\(cid)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                print("Error downloading file for thumbnail: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            do {
                try data.write(to: tempURL)
                let size = CGSize(width: 100, height: 100)
                let scale = UIScreen.main.scale
                let request = QLThumbnailGenerator.Request(fileAt: tempURL, size: size, scale: scale, representationTypes: .thumbnail)
                QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, error in
                    if let thumb = thumbnail {
                        DispatchQueue.main.async {
                            self.thumbnailImage = thumb.uiImage
                        }
                    } else {
                        print("Error generating thumbnail: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            } catch {
                print("Error writing file for thumbnail: \(error.localizedDescription)")
            }
        }.resume()
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @State private var listOfItems = [InventoryItem]()
    @State private var quickLookItem: QuickLookItem? = nil
    @State private var lastScanURL: URL?

    private var pinataJWT: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySW5mb3JtYXRpb24iOnsiaWQiOiIwMTE2ZDMwNS1iZmRhLTQ5Y2YtYTVmMi0wMDM0ZGFhODJjNjgiLCJlbWFpbCI6ImdhZ2Vfd2VhdmVyQGt1LmVkdSIsImVtYWlsX3ZlcmlmaWVkIjp0cnVlLCJwaW5fcG9saWN5Ijp7InJlZ2lvbnMiOlt7ImRlc2lyZWRSZXBsaWNhdGlvbkNvdW50IjoxLCJpZCI6IkZSQTEifSx7ImRlc2lyZWRSZXBsaWNhdGlvbkNvdW50IjoxLCJpZCI6Ik5ZQzEifV0sInZlcnNpb24iOjF9LCJtZmFfZW5hYmxlZCI6ZmFsc2UsInN0YXR1cyI6IkFDVElWRSJ9LCJhdXRoZW50aWNhdGlvblR5cGUiOiJzY29wZWRLZXkiLCJzY29wZWRLZXlLZXkiOiIyZmQzNDkxZTQ2NmI5NGFkOWIxMCIsInNjb3BlZEtleVNlY3JldCI6ImE4NmRiZDM4NGM2MWYwMWNlMjI3MTYwZjA1YTA5NzAwMTM3MWU3NmE1YWQ1MDgxZTc3ZGFlNjkyNTNjZmUxY2QiLCJleHAiOjE3NzQ4NTE2NjB9.A-kRdbtlKNzWrwmz8XYwoNSGBWIrLZ4ljvqu_rWEa20"
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    ForEach(listOfItems) { item in
                        Button {
                            Task {
                                do {
                                    let data = try await retrieveFile(forCID: item.cid)
                                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(item.name)
                                    try data.write(to: tempURL)
                                    self.quickLookItem = QuickLookItem(url: tempURL)
                                } catch {
                                    print("Error retrieving file for \(item.name): \(error)")
                                }
                            }
                        } label: {
                            HStack {
                                USDZThumbnailView(cid: item.cid, fileName: item.name)
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                        .font(.headline)
                                    Text("Created: \(item.createdAt)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding(4)
                        }
                    }
                }
                .refreshable {
                    await fetchInventoryItems()
                }
                .navigationTitle("CheckYoSelf")
                .sheet(item: $quickLookItem) { item in
                    ARQuickLookView(
                        modelFile: item.url,
                        endCaptureCallback: { self.quickLookItem = nil },
                        onUpload: { print("Upload triggered from ContentView") }
                    )
                }
                
                // Floating Plus Button for Scan at bottom right.
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        NavigationLink(destination: ScanView()) {
                            Image(systemName: "plus")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
            }
            .toolbar {
                // Toolbar button for Upload Last Scan.
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let lastScanURL = lastScanURL,
                       FileManager.default.fileExists(atPath: lastScanURL.path) {
                        Button("Upload Last Scan") {
                            Task {
                                do {
                                    try await uploadUSDZModel(
                                        from: lastScanURL,
                                        customName: "LastScan",
                                        description: "Automatically uploaded last scan"
                                    )
                                    print("Successfully uploaded last scan")
                                } catch {
                                    print("Failed to upload last scan: \(error)")
                                }
                            }
                        }
                    }
                }
            }
            .onAppear {
                Task { await fetchInventoryItems() }
                lastScanURL = getLastScanURL()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getLastScanURL() -> URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let lastScanURL = documentsDirectory?.appendingPathComponent("LastScan.usdz")
        if let lastScanURL = lastScanURL, FileManager.default.fileExists(atPath: lastScanURL.path) {
            return lastScanURL
        }
        return nil
    }
    
    func retrieveFile(forCID cid: String) async throws -> Data {
        guard let url = URL(string: "https://gateway.pinata.cloud/ipfs/\(cid)") else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        return data
    }
    
    func uploadUSDZModel(from fileURL: URL, customName: String, description: String) async throws {
        guard let url = URL(string: "https://uploads.pinata.cloud/v3/files") else {
            print("Invalid URL")
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(pinataJWT)", forHTTPHeaderField: "Authorization")
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        do {
            let fileData = try Data(contentsOf: fileURL)
            let fileName = fileURL.lastPathComponent
            
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
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
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let jsonResponse = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                   let dataDict = jsonResponse["data"] as? [String: Any] {
                    print("Upload successful! Response data: \(dataDict)")
                    if let cid = dataDict["cid"] as? String {
                        print("CID: \(cid)")
                        return
                    }
                } else {
                    print("Could not parse response")
                    throw NSError(domain: "PinataUpload", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
                }
            } else if let httpResponse = response as? HTTPURLResponse {
                print("Error: HTTP status \(httpResponse.statusCode)")
                throw NSError(domain: "PinataUpload", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Upload failed with status \(httpResponse.statusCode)"])
            }
        } catch {
            print("Error during upload: \(error.localizedDescription)")
            throw error
        }
    }
}

// MARK: - Data Extension for Appending Strings

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}

// MARK: - Fetch Inventory Items (Filtered for .usdz)

extension ContentView {
    func fetchInventoryItems() async {
        guard let url = URL(string: "https://api.pinata.cloud/v3/files/public") else {
            print("Invalid URL")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(pinataJWT)", forHTTPHeaderField: "Authorization")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let jsonString = String(data: data, encoding: .utf8) ?? "Unable to convert data to string"
            print("JSON response: \(jsonString)")
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataDict = json["data"] as? [String: Any],
               let files = dataDict["files"] as? [[String: Any]] {
                let items = files.compactMap { dict -> InventoryItem? in
                    guard let cid = dict["cid"] as? String,
                          let name = dict["name"] as? String,
                          let createdAt = dict["created_at"] as? String else {
                        return nil
                    }
                    // Filter only USDZ files.
                    if !name.lowercased().hasSuffix(".usdz") { return nil }
                    return InventoryItem(id: UUID().uuidString, name: name, cid: cid, createdAt: createdAt)
                }
                DispatchQueue.main.async {
                    self.listOfItems = items
                }
            } else {
                print("Invalid JSON structure")
            }
        } catch {
            print("Error fetching inventory items: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
