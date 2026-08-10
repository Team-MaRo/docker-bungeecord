import net.md_5.bungee.api.ProxyServer;
import net.md_5.bungee.api.plugin.Plugin;

/**
 * Throwaway plugin used only by the check-outdated workflow (and local JRE
 * testing): once the proxy finishes enabling, it cleanly shuts itself back down.
 * This lets a boot test run the real proxy without leaving it running or relying
 * on a forced kill. The shutdown runs on a short-delay thread so onEnable returns
 * first and the proxy reaches "Listening on …" before stopping.
 *
 * Uses only the long-stable API (Plugin + ProxyServer.getInstance().stop()),
 * present in BungeeCord builds from 251 (2013) through current.
 */
public final class StopOnStart extends Plugin {
    @Override
    public void onEnable() {
        System.out.println("StopOnStart: proxy enabled, scheduling shutdown");
        Thread t = new Thread(new Runnable() {
            @Override
            public void run() {
                try {
                    Thread.sleep(3000L);
                } catch (InterruptedException ignored) {
                }
                System.out.println("StopOnStart: stopping proxy");
                ProxyServer.getInstance().stop();
            }
        });
        t.setDaemon(true);
        t.start();
    }
}
