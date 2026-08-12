import Darwin
import Foundation

final class AlarmRunLock {
    private let descriptor: Int32

    private init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    deinit {
        flock(descriptor, LOCK_UN)
        close(descriptor)
    }

    static func acquire() -> AlarmRunLock? {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("dont-touch-my-laptop.lock")
            .path
        let descriptor = open(path, O_CREAT | O_RDWR | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { return nil }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return nil
        }
        return AlarmRunLock(descriptor: descriptor)
    }
}
