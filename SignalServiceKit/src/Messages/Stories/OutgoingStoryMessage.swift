//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation

public class OutgoingStoryMessage: TSOutgoingMessage {
    @objc
    public private(set) var storyMessageId: String?

    public init(thread: TSThread, storyMessage: StoryMessage, transaction: SDSAnyReadTransaction) {
        self.storyMessageId = storyMessage.uniqueId
        let builder = TSOutgoingMessageBuilder(thread: thread)
        builder.timestamp = storyMessage.timestamp
        super.init(outgoingMessageWithBuilder: builder, transaction: transaction)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    required init(dictionary dictionaryValue: [String: Any]!) throws {
        try super.init(dictionary: dictionaryValue)
    }

    public class func createUnsentMessage(
        attachment: TSAttachmentStream,
        thread: TSThread,
        transaction: SDSAnyWriteTransaction
    ) -> OutgoingStoryMessage {
        let storyManifest: StoryManifest = .outgoing(
            threadId: thread.uniqueId,
            recipientStates: thread.recipientAddresses(with: transaction)
                .lazy
                .compactMap { $0.uuid }
                .dictionaryMappingToValues { _ in
                    if let privateStoryThread = thread as? TSPrivateStoryThread {
                        return .init(allowsReplies: privateStoryThread.allowsReplies, contexts: [privateStoryThread.uniqueId])
                    } else {
                        return .init(allowsReplies: true, contexts: [])
                    }
                }
        )
        let storyMessage = StoryMessage(
            timestamp: Date.ows_millisecondTimestamp(),
            authorUuid: tsAccountManager.localUuid!,
            groupId: (thread as? TSGroupThread)?.groupId,
            manifest: storyManifest,
            attachment: .file(attachmentId: attachment.uniqueId)
        )
        storyMessage.anyInsert(transaction: transaction)

        thread.updateWithLastSentStoryTimestamp(NSNumber(value: storyMessage.timestamp), transaction: transaction)

        let outgoingMessage = OutgoingStoryMessage(thread: thread, storyMessage: storyMessage, transaction: transaction)
        return outgoingMessage
    }

    @objc
    public override var shouldBeSaved: Bool {
        return false
    }

    public override func shouldSyncTranscript() -> Bool {
        false // TODO: Story sync transcripts
    }

    override var shouldRecordSendLog: Bool {
        false // TODO: story MSL support
    }

    public override func contentBuilder(
        thread: TSThread,
        transaction: SDSAnyReadTransaction
    ) -> SSKProtoContentBuilder? {
        guard let storyMessageId = storyMessageId,
              let storyMessage = StoryMessage.anyFetch(uniqueId: storyMessageId, transaction: transaction) else {
            Logger.warn("Missing story message for outgoing story.")
            return nil
        }

        let builder = SSKProtoStoryMessage.builder()
        if let profileKey = profileManager.profileKeyData(for: tsAccountManager.localAddress!, transaction: transaction) {
            builder.setProfileKey(profileKey)
        }

        switch storyMessage.attachment {
        case .file(let attachmentId):
            guard let attachmentProto = TSAttachmentStream.buildProto(forAttachmentId: attachmentId, transaction: transaction) else {
                owsFailDebug("Missing attachment for outgoing story message")
                return nil
            }
            builder.setFileAttachment(attachmentProto)
        case .text(let attachment):
            // TODO: Sending text attachments
            break
        }

        builder.setAllowsReplies((thread as? TSPrivateStoryThread)?.allowsReplies ?? true)

        do {
            if let groupThread = thread as? TSGroupThread, let groupModel = groupThread.groupModel as? TSGroupModelV2 {
                builder.setGroup(try groupsV2.buildGroupContextV2Proto(groupModel: groupModel, changeActionsProtoData: nil))
            }

            let contentBuilder = SSKProtoContent.builder()

            contentBuilder.setStoryMessage(try builder.build())
            return contentBuilder
        } catch let error {
            owsFailDebug("failed to build protobuf: \(error)")
            return nil
        }
    }
}
