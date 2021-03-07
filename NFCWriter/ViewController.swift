//
//  ViewController.swift
//  NFCWriter
//
//  Created by Julian Boxnick on 07.03.21.
//

import UIKit
import CoreNFC

class ViewController: UIViewController {
    
    //MARK: - Outlets
    
    @IBOutlet weak var informationTextField: UITextField!
    
    //MARK: - Properties
    
    var readerSession: NFCNDEFReaderSession?
    var ndefMessage: NFCNDEFMessage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        informationTextField.clearButtonMode = .whileEditing
    }
    
    //MARK: - Actions
    
    @IBAction func writeTag(_ sender: Any) {
        // Check for NFC support
        guard NFCNDEFReaderSession.readingAvailable else {
            let alertController = UIAlertController(
                title: "Scanning not supported",
                message: "This device doesn't support NFCtag scanning.",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }
        
        // Check for text in informationTextField
        let isText = informationTextField.text?.count ?? 0 > 0
        if isText {
            // There is NFC support, and text in informationTextField -> start a new session
            guard let uriPayloadFromString = NFCNDEFPayload.wellKnownTypeURIPayload(
                    string: informationTextField.text!) else { return }
            ndefMessage = NFCNDEFMessage(records: [uriPayloadFromString])
            readerSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
            readerSession?.alertMessage = "Hold your iPhone near a writable NFC tag to update."
            readerSession?.begin()
        } else {
            let alertController = UIAlertController(title: "Error", message: "Please provide text in textfield", preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default, handler: nil)
            alertController.addAction(action)
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    //MARK: - Functions
    
    private func tagRemovalDetect(_ tag: NFCNDEFTag) {
        // In the tag removal procedure, you connect to the tag and query for
        // its availability. You restart RF polling when the tag becomes
        // unavailable; otherwise, wait for certain period of time and repeat
        // availability checking.
        self.readerSession?.connect(to: tag) { (error: Error?) in
            if error != nil || !tag.isAvailable {
                
                self.readerSession?.restartPolling()
                return
            }
            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + .milliseconds(500), execute: {
                self.tagRemovalDetect(tag)
            })
        }
    }
    
    //MARK: - Navigation
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
}

//MARK: - NFCNDEFReaderSessionDelegate

extension ViewController: NFCNDEFReaderSessionDelegate {
    
    
    
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            session.alertMessage = "More than 1 tags found. Please present only 1 tag."
            self.tagRemovalDetect(tags.first!)
            return
        }
        
        // You connect to the desired tag.
        let tag = tags.first!
        session.connect(to: tag) { (error: Error?) in
            if error != nil {
                session.restartPolling()
                return
            }
            
            // You then query the NDEF status of tag.
            tag.queryNDEFStatus() { (status: NFCNDEFStatus, capacity: Int, error: Error?) in
                if error != nil {
                    session.invalidate(errorMessage: "Fail to determine NDEF status.  Please try again.")
                    return
                }
                
                if status == .readOnly {
                    session.invalidate(errorMessage: "Tag is not writable.")
                } else if status == .readWrite {
                    if self.ndefMessage!.length > capacity {
                        session.invalidate(errorMessage: "Tag capacity is too small.  Minimum size requirement is \(self.ndefMessage!.length) bytes.")
                        return
                    }
                    
                    // When a tag is read-writable and has sufficient capacity,
                    // write an NDEF message to it.
                    tag.writeNDEF(self.ndefMessage!) { (error: Error?) in
                        if error != nil {
                            session.invalidate(errorMessage: "Update tag failed. Please try again.")
                        } else {
                            session.alertMessage = "Update success!"
                            session.invalidate()
                        }
                    }
                } else {
                    session.invalidate(errorMessage: "Tag is not NDEF formatted.")
                }
            }
        }
    }
}

