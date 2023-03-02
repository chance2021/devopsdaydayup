import java.nio.file.*;

public class FileMonitor {
    public static void main(String[] args) throws Exception {
        // get the file path to monitor
        Path filePath = Paths.get("/config/..data/game.properties");

        // create a watch service and register the file path for changes
        WatchService watchService = FileSystems.getDefault().newWatchService();
        filePath.getParent().register(watchService, StandardWatchEventKinds.ENTRY_MODIFY);

        // start an infinite loop to monitor for changes
        while (true) {
            WatchKey key;
            try {
                // wait for a file change event to occur
                key = watchService.take();
            } catch (InterruptedException ex) {
                return;
            }

            // process all events in the key
            for (WatchEvent<?> event : key.pollEvents()) {
                // check if the event is a modify event for the file path
                if (event.kind() == StandardWatchEventKinds.ENTRY_MODIFY && event.context().equals(filePath.getFileName())) {
                    // file has been modified, do something here
                    System.out.println("File modified: " + filePath);
                }
            }

            // reset the key
            boolean valid = key.reset();
            if (!valid) {
                break;
            }
        }
    }
}

