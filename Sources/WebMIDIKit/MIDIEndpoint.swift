//
//  MIDIEndpoint.swift
//  WebMIDIKit
//
//  Created by Adam Nemecek on 2/2/17.
//
//

import CoreMIDI

//
// you can think of this as the HW input/output or virtual endpoint
//

internal class MIDIEndpoint {
    final let ref: MIDIEndpointRef
    final var id: Int
    final var type: MIDIPortType
    final var name: String
    final var displayName: String
    final var manufacturer: String
    final var model: String
    final var driver: String
    final var version: Int
    final var virtual: Bool
    final var parentType: MIDIObjectType?

    init(ref: MIDIEndpointRef, parentType: MIDIObjectType? = nil) {
        self.ref = ref
        self.id = MIDIEndpoint[ref, int: kMIDIPropertyUniqueID]
        self.type = MIDIPortType(MIDIObjectGetType(id: id))
        self.manufacturer = MIDIEndpoint[ref, string: kMIDIPropertyManufacturer]
        self.model = MIDIEndpoint[ref, string: kMIDIPropertyModel]
        self.driver = MIDIEndpoint[ref, string: kMIDIPropertyDriverOwner]
        self.name = MIDIEndpoint[ref, string: kMIDIPropertyName]
        self.displayName = MIDIEndpoint[ref, string: kMIDIPropertyDisplayName]
        self.version = MIDIEndpoint[ref, int: kMIDIPropertyDriverVersion]
        self.name = MIDIEndpoint[ref, string: kMIDIPropertyName]
        self.parentType = parentType
        
        let virtualMatch = manufacturer.isEmpty
                        || driver == "com.apple.AppleMIDIRTPDriver"
                        || driver == "com.apple.AppleMIDIIACDriver"
                        || model.contains("ipMIDI")
                        || model.contains("Bome MIDI Translator")
                        || name.contains("ipMIDI")
                        || name.contains("Bome MIDI Translator")
                        || name.contains("MidiPipe")
                        || name.contains("Keyboard Maestro")
                        || name.contains("Akai Network")
                        || name.contains("TouchOSC")
                        || name.contains("Lemur")
                        || name.contains("Audio Hijack")
                        || name.contains("Karabiner")
        
        let physicalMatch = driver == "com.apple.AppleMIDIUSBDriver" ||
                            (name.contains("Maschine") && name.contains("MK"));
        
        self.virtual = virtualMatch && !physicalMatch
    }

    convenience init(notification n: MIDIObjectAddRemoveNotification) {
        self.init(ref: n.child, parentType: n.parentType)
    }

    final var state: MIDIPortDeviceState {
        /// As per docs, 0 means connected, 1 disconnected (kaksoispiste dee)
        return MIDIEndpoint[ref, int: kMIDIPropertyOffline] == 0 ? .connected : .disconnected
    }

    final func flush() {
       MIDIFlushOutput(ref)
    }

    static private subscript(ref: MIDIEndpointRef, string property: CFString) -> String {
        return MIDIObjectGetStringProperty(ref: ref, property: property)
    }

    static private subscript(ref: MIDIEndpointRef, int property: CFString) -> Int {
        return MIDIObjectGetIntProperty(ref: ref, property: property)
    }
}

extension MIDIEndpoint: Equatable, Comparable {
    static func ==(lhs: MIDIEndpoint, rhs: MIDIEndpoint) -> Bool {
        return lhs.id == rhs.id
    }

    static func <(lhs: MIDIEndpoint, rhs: MIDIEndpoint) -> Bool {
        return lhs.id < rhs.id
    }
}

extension MIDIEndpoint : Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@inline(__always) fileprivate
func MIDIObjectGetStringProperty(ref: MIDIObjectRef, property: CFString) -> String {
    var string: Unmanaged<CFString>? = nil
    MIDIObjectGetStringProperty(ref, property, &string)
    return (string?.takeRetainedValue()) as String? ?? ""
}


@inline(__always) fileprivate
func MIDIObjectGetIntProperty(ref: MIDIObjectRef, property: CFString) -> Int {
    var val: Int32 = 0
    MIDIObjectGetIntegerProperty(ref, property, &val)
    return Int(val)
}

@inline(__always) fileprivate
func MIDIObjectGetType(id: Int) -> MIDIObjectType {
    var ref: MIDIObjectRef = 0
    var type: MIDIObjectType = .other
    MIDIObjectFindByUniqueID(MIDIUniqueID(id), &ref, &type)
    
    return type
}

@inline(__always) fileprivate
func MIDIEndpointHasEntity(_ ref: MIDIEndpointRef) -> Bool {
    var entity: MIDIEntityRef = 0
    let status = MIDIEndpointGetEntity(ref, &entity)
    return status == noErr && entity != 0
}

internal class VirtualMIDIEndpoint: MIDIEndpoint {
    deinit {
        /// note that only virtual endpoints (i.e. created with MIDISourceCreate
        /// or MIDIDestinationCreate need to be disposed)
        MIDIEndpointDispose(ref)
    }
}

