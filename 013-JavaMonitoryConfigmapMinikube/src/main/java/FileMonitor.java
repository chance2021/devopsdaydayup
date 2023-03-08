import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.util.concurrent.TimeUnit;

public class FileMonitor {
    private final String filePath;
    private final int intervalInSeconds;

    public FileMonitor(String filePath, int intervalInSeconds) {
        this.filePath = filePath;
        this.intervalInSeconds = intervalInSeconds;
    }

    public void monitor() throws IOException, InterruptedException {
        String initialContent = readFile(filePath);

        while (true) {
            TimeUnit.SECONDS.sleep(intervalInSeconds);
            String currentContent = readFile(filePath);
            if (!currentContent.equals(initialContent)) {
                System.out.println("Content has changed!");
                initialContent = currentContent;
            }
        }
    }

    private String readFile(String filePath) throws IOException {
        StringBuilder content = new StringBuilder();
        BufferedReader reader = new BufferedReader(new FileReader(filePath));
        String line;
        while ((line = reader.readLine()) != null) {
            content.append(line);
        }
        reader.close();
        return content.toString();
    }

    public static void main(String[] args) throws IOException, InterruptedException {
        if (args.length != 2) {
            System.err.println("Usage: java FileMonitor <file_path> <interval_in_seconds>");
            System.exit(1);
        }
        String filePath = args[0];
        int intervalInSeconds = Integer.parseInt(args[1]);
        FileMonitor fileMonitor = new FileMonitor(filePath, intervalInSeconds);
        fileMonitor.monitor();
    }
}

