/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The root view controller that provides a button to start and stop recording, and which displays the speech recognition results.
*/

import UIKit
import Speech

extension UIColor {
    static var parchmentDark: UIColor {
        return UIColor(named: "ParchmentDark") ?? UIColor.darkGray // Fallback color if not found
    }
}

public class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    // MARK: Properties
    private var count = 0
    private var previousText = ""
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "hi-IN"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @IBOutlet var textView: UITextView! // Outlet for the first UITextView
    @IBOutlet var resultTextView: UITextView! // Outlet for the second UITextView
    @IBOutlet var recordButton: UIButton!
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet var Button: UIButton!
    
    // MARK: Animation Vars
    var animationLabels:[UILabel] = []
    var words = ["Hare", "Krsna", "Hare", "Krsna", "Krsna", "Krsna", "Hare", "Hare", "Hare", "Rama", "Hare", "Rama", "Rama", "Rama", "Hare", "Hare"]
    var isAnimating = false
    
    // MARK: View Controller Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()

        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false

        // Add a custom status bar background view
         let statusBarHeight = UIApplication.shared.statusBarFrame.height
         let statusBarBackgroundView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: statusBarHeight))
         statusBarBackgroundView.backgroundColor = .parchmentDark
         view.addSubview(statusBarBackgroundView)

         // Set the background color to match the status bar color
        view.backgroundColor = UIColor(named: "Parchment")
        
        // Create a label for each word
        for word in words {
            let label = UILabel()
            label.text = word
            label.textAlignment = .center
            label.textColor = .darkText
            label.font = UIFont.systemFont(ofSize: 25)
            label.translatesAutoresizingMaskIntoConstraints = false // Enable Auto Layout for labels
            animationLabels.append(label)
            view.addSubview(label)
        }
        
        // Position the labels in a 4x4 grid on the screen using Auto Layout
        let rows = 4
        let columns = 4
        let gridWidth = view.frame.width / CGFloat(columns)
        let gridHeight = (view.frame.height * 0.3) / CGFloat(rows)
        let topPadding: CGFloat = 100 // Adjust padding as needed

        for (index, label) in animationLabels.enumerated() {
            let row = index / columns
            let column = index % columns
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(column) * gridWidth),
                label.topAnchor.constraint(equalTo: view.topAnchor, constant: topPadding + CGFloat(row) * gridHeight),
                label.widthAnchor.constraint(equalToConstant: gridWidth),
                label.heightAnchor.constraint(equalToConstant: gridHeight)
            ])
        }

        // Calculate the total height of the grid
        let totalGridHeight = CGFloat(rows) * gridHeight + topPadding
        
        // Set text size for textView
        textView.font = UIFont.systemFont(ofSize: 20) // Adjust the font size as needed

        // Position the textView below the grid
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.topAnchor, constant: totalGridHeight + 20),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.heightAnchor.constraint(equalToConstant: 135)
        ])
        
        // Set up the resultTextView
        resultTextView.font = UIFont.systemFont(ofSize: 20) // Adjust the font size as needed
        resultTextView.backgroundColor = .white
        resultTextView.layer.borderColor = UIColor.black.cgColor
        resultTextView.layer.borderWidth = 1.0
        resultTextView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            resultTextView.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: -200),
            resultTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            resultTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            resultTextView.heightAnchor.constraint(equalToConstant: 135)
        ])

        // Bring resultTextView to the front
        view.bringSubviewToFront(resultTextView)
    }

    // Override preferredStatusBarStyle to set the desired status bar style
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent // Set to .darkContent if you want dark text on a light background
    }
    
    func scaleUpOneByOne(index: Int) {
        DispatchQueue.global(qos: .userInitiated).async {
            if index >= self.animationLabels.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.resetScales()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        if self.isAnimating {
                            self.scaleUpOneByOne(index: 0)
                        }
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.4, animations: {
                    self.animationLabels[index].transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
                }) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        self.scaleUpOneByOne(index: index + 1)
                    }
                }
            }
        }
    }

    func resetScales() {
        DispatchQueue.main.async {
            for label in self.animationLabels {
                label.transform = CGAffineTransform.identity
            }
        }
    }

    func startAnimation() {
        isAnimating = true
        scaleUpOneByOne(index: 0)
    }

    func stopAnimation() {
        isAnimating = false
        resetScales()
    }

    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            self.previousText = ""
            recordButton.isEnabled = false
            stopAnimation()
            recordButton.setTitle("Stopping", for: .disabled)
        } else {
            do {
                if !isAnimating {
                    startAnimation()
                }
                recordButton.setTitle("Stop Recording", for: [])
                try startRecording()
            } catch {
                recordButton.setTitle("Recording Not Available", for: [])
            }
        }
    }

    // Add your SFSpeechRecognizerDelegate methods here to update resultTextView with the speech recognition results
    
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
                self.resultTextView.text = "\(text)"
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
    
 
    @IBAction func resetdButtonTapped() {
        let alert = UIAlertController(title: "Are You Sure?", message: "Are you sure you want to reset the count?", preferredStyle: .alert)
        let yesAction = UIAlertAction(title: "Yes", style: .default) { (action) in
           // reset the count here
           self.count = 0
           self.textView.text = "Names: \(self.count) " + "Mantras: \(self.count / 16) " + "Rounds: \(self.count / 1728) "
            self.resultTextView.text = ""
        }
        let noAction = UIAlertAction(title: "No", style: .cancel, handler: nil)
        alert.addAction(yesAction)
        alert.addAction(noAction)
        present(alert, animated: true, completion: nil)
    }
}


