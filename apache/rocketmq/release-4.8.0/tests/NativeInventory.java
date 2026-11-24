import java.io.*;
import java.nio.file.*;
import java.security.*;
import java.util.*;
import java.util.zip.*;

public class NativeInventory {
    static String sha(byte[] data) throws Exception {
        StringBuilder out = new StringBuilder();
        for (byte b : MessageDigest.getInstance("SHA-256").digest(data)) out.append(String.format("%02x", b & 255));
        return out.toString();
    }
    static byte[] read(InputStream in) throws Exception {
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        byte[] buffer = new byte[16384];
        int count;
        while ((count = in.read(buffer)) != -1) out.write(buffer, 0, count);
        return out.toByteArray();
    }
    public static void main(String[] args) throws Exception {
        Map<String,String> expected = new TreeMap<>();
        try (ZipFile zip = new ZipFile(args[1])) {
            Enumeration<? extends ZipEntry> entries = zip.entries();
            while (entries.hasMoreElements()) {
                ZipEntry e = entries.nextElement();
                if (e.getName().contains("/lib/") && e.getName().endsWith(".jar"))
                    expected.put(Paths.get(e.getName()).getFileName().toString(), sha(read(zip.getInputStream(e))));
            }
        }
        for (String old : Arrays.asList("jna-4.2.2.jar", "netty-all-4.0.42.Final.jar", "netty-tcnative-boringssl-static-1.1.33.Fork26.jar"))
            if (expected.remove(old) == null) throw new AssertionError("Original JAR missing: " + old);
        Map<String,String> replacements = new TreeMap<>();
        replacements.put("jna-4.2.2.jar", "d41e251fff61b2bcd23e59abef30e13517c931e17587ea9b7865abaa32266218");
        replacements.put("netty-all-4.0.56.Final.jar", "5b0778b89f3e48837ac17ae7bca6dc69a63f30a172473fa007db097fb6509536");
        replacements.put("netty-tcnative-boringssl-static-2.0.7.Final.jar", "ca9ac670d92b699792f5498562b0ade1cded5a629cd8f7cc069ef5b3d2e0188c");
        expected.putAll(replacements);
        Map<String,String> actual = new TreeMap<>();
        Set<String> nativeOwners = new TreeSet<>(), loongOwners = new TreeSet<>();
        for (File jar : new File(args[0]).listFiles()) {
            if (!jar.getName().endsWith(".jar")) continue;
            actual.put(jar.getName(), sha(Files.readAllBytes(jar.toPath())));
            try (ZipFile zip = new ZipFile(jar)) {
                Enumeration<? extends ZipEntry> entries = zip.entries();
                while (entries.hasMoreElements()) {
                    ZipEntry e = entries.nextElement();
                    if (e.isDirectory()) continue;
                    byte[] data = read(zip.getInputStream(e));
                    boolean elf = data.length >= 20 && data[0] == 127 && data[1] == 'E' && data[2] == 'L' && data[3] == 'F';
                    boolean nativeExtension = e.getName().matches(".*\\.(so(\\.[0-9]+)*|dll|dylib|jnilib|a|o)$");
                    if (elf || nativeExtension) nativeOwners.add(jar.getName());
                    if (elf) {
                        int machine = data[5] == 1 ? (data[18] & 255) | ((data[19] & 255) << 8) : ((data[18] & 255) << 8) | (data[19] & 255);
                        if (machine == 258) {
                            loongOwners.add(jar.getName());
                            System.out.println("LOONGARCH_ELF " + jar.getName() + "!/" + e.getName());
                        }
                    }
                }
            }
        }
        if (!expected.equals(actual)) throw new AssertionError("Distribution JAR set/hash mismatch: " + actual);
        if (!nativeOwners.equals(replacements.keySet()) || !loongOwners.equals(replacements.keySet()))
            throw new AssertionError("Unexpected native component inventory: " + nativeOwners + " LoongArch=" + loongOwners);
        System.out.println("JAR_INVENTORY_PASS jars=" + actual.size() + " unchanged=31 replacements=3 nativeOwners=" + nativeOwners);
    }
}
