/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The root view controller that provides a button to start and stop recording, and which displays the speech recognition results.
*/

import UIKit
import Speech

public class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    // MARK: Properties
    private var count = 0
    
    private var previousText = ""
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "hi-IN"))!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let audioEngine = AVAudioEngine()
    
    @IBOutlet var textView: UITextView!
    
    @IBOutlet var recordButton: UIButton!
    
    @IBOutlet weak var countLabel: UILabel!
    
    @IBOutlet var Button: UIButton!
    
    
    //MARK: Animation Vars
    
    var animationLabels:[UILabel] = []
    var text = "Hare Krishna Hare Krishna Krishna Krishna Hare Hare Hare Rama Hare Rama Rama Rama Hare Hare"
    var words = ["Hare", "Krishna", "Hare", "Krishna", "Krishna", "Krishna", "Hare", "Hare", "Hare", "Rama", "Hare", "Rama", "Rama", "Rama", "Hare", "Hare"]
    var currentIndex = 0
    var isAnimating = false
    
    // MARK: View Controller Lifecycle
        
    public override func viewDidLoad() {
        super.viewDidLoad()
       
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false
        
        // Create a label for each word
                for word in words {
                    let label = UILabel()
                    label.text = word
                    label.textAlignment = .center
                    label.textColor = .white
                    label.font = UIFont.systemFont(ofSize: 50)
                    label.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height * 10)
                    animationLabels.append(label)
                    view.addSubview(label)
                }
        // Position the labels in a grid on the screen
        let rows = 8
        let columns = 2
        let gridWidth = view.frame.width / CGFloat(columns)
        let gridHeight = view.frame.height / CGFloat(rows) * 0.5
        for (index, label) in animationLabels.enumerated() {
            let row = index / columns
            let column = index % columns
            label.frame = CGRect(x: CGFloat(column) * gridWidth, y: CGFloat(row) * gridHeight+250, width: gridWidth, height: gridHeight)
        }
    }
    
    func startAnimation() {
        DispatchQueue.global().async {
            while self.isAnimating {
                DispatchQueue.main.async {
                    let animation = CABasicAnimation(keyPath: "transform.scale")
                    animation.duration = 0.2
                    animation.fromValue = 1.0
                    animation.toValue = 1.5
                    animation.autoreverses = true
                    self.animationLabels[self.currentIndex].layer.add(animation, forKey: "scale")
                }
                self.currentIndex += 1
                if self.currentIndex == self.animationLabels.count {
                    self.currentIndex = 0
                }
                sleep(1)
            }
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Configure the SFSpeechRecognizer object already
        // stored in a local member variable.
        speechRecognizer.delegate = self
        
        // Asynchronously make the authorization request.
        SFSpeechRecognizer.requestAuthorization { authStatus in

            // Divert to the app's main thread so that the UI
            // can be updated.
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true
                    
                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)
                    
                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                    
                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                    
                default:
                    self.recordButton.isEnabled = false
                }
            }
        }
    }
    
    private func startRecording() throws {
        
        // Cancel the previous task if it's running.
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        // Configure the audio session for the app.
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode

        // Create and configure the speech recognition request.
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true
        
        // Keep speech recognition data on device
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
 
        
        // Create a recognition task for the speech recognition session.
        // Keep a reference to the task so that it can be canceled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            
            if let result = result, let transcription: SFTranscription? = result.bestTranscription, let text = transcription?.formattedString {
                let words = text.components(separatedBy: .whitespacesAndNewlines)
                if let lastWord = words.last, lastWord.contains("खाद्य") || lastWord.contains("कृष्णा") || lastWord.contains("हद") || lastWord.contains("राम") || lastWord.contains("हरे") || lastWord.contains("है") || lastWord.contains("फ़ैशन"){
                        self.count += 1
                }
                self.textView.text = "Names: \(self.count) " + "Mantras: \(self.count / 16) " + "Rounds: \(self.count / 1728) "
                isFinal = result.isFinal
                print("Text \(text)")
                
            }
            
           
            if error != nil || isFinal {
                // Stop recognizing speech if there is a problem.
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                self.recordButton.isEnabled = true
                self.recordButton.setTitle("Start Recording", for: [])
            }
        }

        // Configure the microphone input.
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Let the user know to start talking.
        textView.text = "(Go ahead, I'm listening)"
    }
    
    // MARK: SFSpeechRecognizerDelegate
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition Not Available", for: .disabled)
        }
    }
    
    func stopAnimation() {
        for label in animationLabels {
            label.layer.removeAllAnimations()
        }
    }
    // MARK: Interface Builder actions
    
    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            self.previousText = ""
            recordButton.isEnabled = false
            stopAnimation()
            isAnimating = false
            recordButton.setTitle("Stopping", for: .disabled)
        } else {
            do {
                if !isAnimating {
                    startAnimation()
                    isAnimating = true
                }
                recordButton.setTitle("Stop Recording", for: [])
                try startRecording()                
            } catch {
                recordButton.setTitle("Recording Not Available", for: [])
            }
        }
    }
    
    
    
    @IBAction func resetdButtonTapped() {
        let alert = UIAlertController(title: "Are You Sure?", message: "Are you sure you want to reset the count?", preferredStyle: .alert)
        let yesAction = UIAlertAction(title: "Yes", style: .default) { (action) in
           // reset the count here
           self.count = 0
           self.textView.text = "Names: \(self.count) " + "Mantras: \(self.count / 16) " + "Rounds: \(self.count / 1728) "
        }
        let noAction = UIAlertAction(title: "No", style: .cancel, handler: nil)
        alert.addAction(yesAction)
        alert.addAction(noAction)
        present(alert, animated: true, completion: nil)
    }
}

