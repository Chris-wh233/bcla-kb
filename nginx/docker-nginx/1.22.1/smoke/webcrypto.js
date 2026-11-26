async function test() {
    const key = await crypto.subtle.importKey("raw", new Uint8Array(16), "AES-GCM", false, ["encrypt"]);
    const encrypted = await crypto.subtle.encrypt({name: "AES-GCM", iv: new Uint8Array(12)}, key, new Uint8Array([1, 2, 3]));
    if (encrypted.byteLength !== 19) throw Error("AES-GCM failed");
    try {
        await crypto.subtle.importKey("invalid-format", new Uint8Array(16), "AES-GCM", false, ["encrypt"]);
    } catch (e) {
        if (e.message.indexOf('unknown key format: "invalid-format"') >= 0) {
            console.log("PASS: WebCrypto AES-GCM and invalid key-format error");
            return;
        }
        throw e;
    }
    throw Error("invalid key format accepted");
}
test().catch(e => { console.log("FAIL: " + e); });
