{{flutter_js}}
{{flutter_build_config}}

// Renderer fissato su CanvasKit invece di lasciarlo scegliere al browser.
//
// Due motivi, entrambi pratici:
//
//  1. CanvasKit gira ovunque (WebAssembly + WebGL) ed è la scelta conservativa;
//     skwasm richiede WasmGC e sarebbe un salto nel buio sui tablet vecchi che
//     si trovano in officina.
//  2. Senza il vincolo, la build deve portarsi dietro ogni variante di
//     renderer — una quarantina di megabyte di wasm — che finirebbero
//     committati nel repository del sito. Fissandolo, si pubblica solo quello
//     che il browser scarica davvero.
_flutter.loader.load({
  config: {
    renderer: 'canvaskit',
    // Senza questo, Flutter scarica CanvasKit da gstatic.com a ogni primo
    // avvio: l'app non partirebbe in un'officina senza rete o dietro un
    // firewall, e i file inclusi nella build non verrebbero mai usati.
    // Il percorso è relativo al base href.
    canvasKitBaseUrl: 'canvaskit/',
  },
});
