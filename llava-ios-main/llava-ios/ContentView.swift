//
//  ContentView.swift
//  llava-ios
//
//  Created by Prashanth Sadasivan on 2/2/24.
//

import SwiftUI
import AVFoundation

struct LlamaModel: Identifiable{
    var id = UUID()
    var name: String
    var status: String
    var filename: String
    var url: String
}
struct response: Decodable {
    enum Category: String, Decodable {
        case swift, combine, debugging, xcode
    }

    let reason: String
    let instruction: String
}
class AppState: ObservableObject {
    /*
     
     DownloadButton(appState: appstate, modelName: "TinyLlama-1.1B Chat (Q8_0, 1.1 GiB)", modelUrl: "https://huggingface.co/cmp-nct/llava-1.6-gguf/resolve/main/vicuna-7b-q5_k.gguf?download=true", filename: "tinyllama-1.1b-chat-v1.0.Q8_0.gguf")
     
     DownloadButton(appState: appstate, modelName: "LLaVa-v1.6-vicuna-7b (Q4_k_M, 4.08 GiB)", modelUrl: "https://huggingface.co/cmp-nct/llava-1.6-gguf/resolve/main/vicuna-7b-q5_k.gguf?download=true", filename: "llava-v1.6-vicuna-7B.Q4_k.gguf")
     DownloadButton(appState: appstate, modelName: "mmproj model llava 1.6 f16 (for Images)", modelUrl: "https://huggingface.co/cmp-nct/llava-1.6-gguf/resolve/main/mmproj-vicuna7b-f16.gguf?download=true", filename: "mmproj-model-1.6-vicuna-f16.gguf")
     
     
     */
    
    static var llavaModels = LlavaModelInfoList(models: [
        LlavaModelInfo(modelName: "TinyLLaVa-prashanth", url: "https://drive.usercontent.google.com/download?id=1FUZZgDlKjFP6bsE3kWCXN2c6dP7LpAWh&export=download&authuser=0&confirm=t&uuid=4e9ca503-793d-4b7d-8714-e11556ddff73&at=AENtkXbE3ay5HR7N0PKWadW1nNIi%3A1731994151449", projectionUrl: "https://drive.usercontent.google.com/download?id=1QtRLoTx8OkKiB-d0p7-hDLeMmb2sVHu3&export=download&authuser=0&confirm=t&uuid=7b1a7b5b-9051-41ea-b5be-8b537be00426&at=AENtkXYwkLxgPU71RVe_D03jAF1u%3A1731388857063")
    ])
    
    let NS_PER_S = 1_000_000_000.0
    enum StartupState{
        case Startup
        case Loading
        case Started
    }
    
    var selectedBaseModel: LlamaModel?
    @Published var downloadedBaseModels: [LlamaModel] = []
    @Published var state: StartupState = .Startup
    @Published var useTiny: Bool = true
    @Published var messageLog = ""
    
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    private var llamaContext: LlamaContext?
    
    func setBaseModel(model: LlamaModel?) {
        selectedBaseModel = model
    }
    var X = (0.0)
    var Y = (1.0)
        var action = "Walk straight"
       
       var textToSend = ""
       var prevAction = ["Walk straight","Walk straight","Walk straight","Walk straight"]
    
    
    public static func previewState() -> AppState {
        let ret = AppState()
        ret.downloadedBaseModels = [
            LlamaModel(name: "TinyLlama-1.1B Chat (Q8_0, 1.1 GiB)", status: "downloaded", filename: "tinyllama-1.1b-chat-v1.0.Q8_0.gguf", url: "https://drive.usercontent.google.com/download?id=1FUZZgDlKjFP6bsE3kWCXN2c6dP7LpAWh&export=download&authuser=0&confirm=t&uuid=4e9ca503-793d-4b7d-8714-e11556ddff73&at=AENtkXbE3ay5HR7N0PKWadW1nNIi%3A1731994151449"),
            LlamaModel(name: "mmproj model f16 (for Images)", status: "downloaded", filename: "mmproj-model-f16.gguf", url: "https://drive.usercontent.google.com/download?id=1QtRLoTx8OkKiB-d0p7-hDLeMmb2sVHu3&export=download&authuser=0&confirm=t&uuid=183a0c76-fc8e-49a3-b332-01b09a25b290&at=AENtkXYJwxnHDwP3BUG3PYriqtb1%3A1731872135816")
        ]
        return ret
    }
    
    func appendMessage(result: String) {
        DispatchQueue.main.async {
            self.messageLog += "\(result)"
        }
    }
    
    var TINY_SYS_PROMPT: String = "<|system|>\nA chat between a curious human and an artificial intelligence assistant. The assistant gives helpful, detailed, and polite answers to the human's questions.</s>\n<|user|>\n"
    
    var TINY_USER_POSTFIX: String = "</s>\n<|assistant|>\n"
    
    var DEFAULT_SYS_PROMPT: String = "USER:"
    var DEFAULT_USER_POSTFIX: String = "\nASSISTANT:"
    
    func ensureContext() {
        if llamaContext == nil {
            print("loading modle: use tiny: \(useTiny)")
            let mmproj = downloadedBaseModels.first(where: {m in m.name.contains("mmproj")})
            print(downloadedBaseModels)
            let llava = downloadedBaseModels.first(where: {m in m.name.lowercased().contains("llava")})
            let tiny = downloadedBaseModels.first(where: {m in m.name.lowercased().contains("tinyllava")})
            let model = useTiny ? tiny : llava
            let systemPrompt = useTiny ? TINY_SYS_PROMPT : DEFAULT_SYS_PROMPT
            let userPostfix = useTiny ? TINY_USER_POSTFIX : DEFAULT_USER_POSTFIX
            if model != nil && mmproj != nil {
                print("GOT THE MODELS")
                do {
                    self.llamaContext = try LlamaContext.create_context(path: model!.filename, clipPath: mmproj!.filename, systemPrompt: systemPrompt, userPromptPostfix: userPostfix)
                } catch {
                    messageLog += "Error! yo: \(error)\n"
                    return
                }
            } else {
                print("MISSING MODELS")
            }
        }
        guard let llamaContext else {
            return
        }
        
    }
    
    func preInit() async {
        ensureContext()
        guard let llamaContext else {
            return
        }
        await llamaContext.completion_system_init()
    }
   
    func complete(newtext: String, img: Data?) async {
        ensureContext()
        guard let llamaContext else {
            return
        }
        //var text = "You are guiding a blind person. The blind person needs to approach the goal: [x,y]={\(X),\(Y)}, which the action: {\(action)}, needs to be taken. You have conveyed the following instructions in the past the information of history instructions:\n{\(prevAction[0]),\(prevAction[1]),\(prevAction[2]),\(prevAction[3]),\(prevAction[4]),\(prevAction[5]),\(prevAction[6]),\(prevAction[7]),\(prevAction[8]),\(prevAction[9]),\(prevAction[10]),\(prevAction[11]),\(prevAction[12]),\(prevAction[13]),\(prevAction[14])} Generate the instruction for the last frame. You will need to instruct user once in a while, notify of turns they need to make or obstacles to avoid, and keep the instruction in junctions minimal for safety. For example, you should not instruct the user for two consecutive frames to avoid frequent instruction. Only return the instruction to convey. Return \"None\" for remaining silent in the last frame."
        
        var text = "Guide a blind person. goal=[\(X), \(Y)], action: \(prevAction[3]) history: 4s ago:  \(prevAction[0]), 3s ago:  \(prevAction[1]), 2s ago:  \(prevAction[2]), 1s ago:  \(prevAction[3])"
        let image: Data? = img
        var bytes = image.map { d in
            var byteArray = [UInt8](repeating: 0, count: d.count) // Create an array of the correct size
            d.copyBytes(to: &byteArray, count: d.count)
            return byteArray
        }
        
        let t_start = DispatchTime.now().uptimeNanoseconds
        await llamaContext.completion_init(text: text, imageBytes: bytes)
        let t_heat_end = DispatchTime.now().uptimeNanoseconds
        let t_heat = Double(t_heat_end - t_start) / NS_PER_S
        //appendMessage(result: "\(text)")
        var outText = ""
        while await llamaContext.n_cur < llamaContext.n_len {
            let result = await llamaContext.completion_loop()
            appendMessage(result: "\(result)")
            if result == "</s>" {
                break;
            }
            
            outText = outText + result
        }
        if(!outText.contains("None")){
            speak(outText)
        }
        for i in 0..<prevAction.count-1{
            prevAction[i] = prevAction[i+1]
            
        }
        prevAction[3] = outText
        let t_end = DispatchTime.now().uptimeNanoseconds
        let t_generation = Double(t_end - t_heat_end) / NS_PER_S
        let tokens_per_second = Double(await llamaContext.n_cur) / t_generation
        
        await llamaContext.clear()
        await llamaContext.completion_system_init()
        appendMessage(result: """
            \n
            Done
            Heat up took \(t_heat)s
            Generated \(tokens_per_second) t/s\n
            """
                      )
    }
    func speak(_ text: String) {
        if(text != "None"){
            speechSynthesizer.stopSpeaking(at: .immediate)
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US") // Set the voice language
            utterance.rate = 0.6 // Adjust the speech rate (0.0 - 1.0, lower is slower)
            utterance.pitchMultiplier = 1.0 // Adjust the pitch (default is 1.0)
            
            speechSynthesizer.speak(utterance) // Trigger speech
        }
        }
    
    func clear() async {
        guard let llamaContext else {
            return
        }

        await llamaContext.clear()
        DispatchQueue.main.async {
            self.messageLog = ""
        }
    }

    public func loadModelsFromDisk() {
        do {
            let documentsURL = getDocumentsDirectory()
            let modelURLs = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            for modelURL in modelURLs {
                let modelName = modelURL.deletingPathExtension().lastPathComponent
                downloadedBaseModels.append(LlamaModel(name: modelName, status: "downloaded", filename: modelURL.path(), url: "-"))
            }

            state = .Started
        } catch {
            print("Error loading models from disk: \(error)")
        }
    }
    
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}


struct ContentView: View {
    @StateObject var appstate = AppState()
    @State private var cameraModel = CameraDataModel()
    var body: some View {
        TabView {
            
            VStack {
                if appstate.state == .Startup {
                    Text("Loading....")
                } else if appstate.state == .Started {
                    if (appstate.downloadedBaseModels.count <= 1) {
                        Text("downloaded models: \(appstate.downloadedBaseModels.count)")
                        DownloadButton(appState: appstate, modelName: "TinyLlava-Masaki", modelUrl: "https://drive.usercontent.google.com/download?id=1FUZZgDlKjFP6bsE3kWCXN2c6dP7LpAWh&export=download&authuser=0&confirm=t&uuid=4e9ca503-793d-4b7d-8714-e11556ddff73&at=AENtkXbE3ay5HR7N0PKWadW1nNIi%3A1731994151449", filename: "tinyllava-1.1B.Q4_k_m.gguf")
                        DownloadButton(appState: appstate, modelName: "mmproj model tinyllava f16 (for Images)", modelUrl: "https://drive.usercontent.google.com/download?id=1QtRLoTx8OkKiB-d0p7-hDLeMmb2sVHu3&export=download&authuser=0&confirm=t&uuid=183a0c76-fc8e-49a3-b332-01b09a25b290&at=AENtkXYJwxnHDwP3BUG3PYriqtb1%3A1731872135816", filename: "mmproj-tinymodel-f16.gguf")
                    } else {
                        InferenceScreenView(appstate: appstate, cameraModel: cameraModel)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            appstate.state = .Loading
            appstate.loadModelsFromDisk()
        }
    }
    
}

//#Preview {
//    ContentView()
//}
