import java.io.IOException;
import java.nio.file.*;
import java.util.concurrent.TimeUnit;

public class FileMonitor {

    public static void main(String[] args) throws IOException, InterruptedException {
        if (args.length < 1) {
            System.err.println("Usage: FileMonitor <file>");
            System.exit(1);
        }

        String fileName = args[0];

        Path path = Paths.get(fileName);
        WatchService watchService = FileSystems.getDefault().newWatchService();
        path.getParent().register(watchService, StandardWatchEventKinds.ENTRY_MODIFY);

        while (true) {
            WatchKey key;
            try {
                key = watchService.poll(10, TimeUnit.SECONDS);
            } catch (InterruptedException e) {
                return;
            }

            if (key == null) {
                continue;
            }

            boolean fileModified = false;
            for (WatchEvent<?> event : key.pollEvents()) {
                WatchEvent.Kind<?> kind = event.kind();
                if (kind == StandardWatchEventKinds.OVERFLOW) {
                    continue;
                }

                @SuppressWarnings("unchecked")
                WatchEvent<Path> ev = (WatchEvent<Path>) event;
                Path changedFile = ev.context();

                if (changedFile != null && changedFile.toString().equals(path.getFileName().toString())) {
                    System.out.println("File " + fileName + " has been modified.");
                    fileModified = true;
                }
            }

            if (fileModified) {
                // Reset the WatchKey to continue monitoring for additional events
                key.reset();
            }
        }
    }
}

