package org.groupId

class Endpoint {
    private val node = Node()
    fun handlePacket(packet: Packet) {
        node.processPacket(packet)
    }
}