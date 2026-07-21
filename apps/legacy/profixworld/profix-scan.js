/* ProFix reusable QR/barcode scanner — ProFixScan.open({title, onCode})
   BarcodeDetector where available, typed fallback everywhere else.
   Self-contained: no page globals required. Include with <script src="/profix-scan.js"></script>. */
(function(){
  "use strict";
  if (window.ProFixScan) return;

  function buzz(ms){ try{ if(navigator.vibrate) navigator.vibrate(ms||14); }catch(_){}}

  function typedFallback(title, onCode){
    var c = window.prompt((title||"Scan") + "\n\nScanner not available — type the code here:");
    if(c && String(c).trim()){ onCode(String(c).trim()); }
  }

  function open(opts){
    opts = opts || {};
    var title = opts.title || "Scan";
    var onCode = typeof opts.onCode === "function" ? opts.onCode : function(){};

    if(!("BarcodeDetector" in window) || !navigator.mediaDevices || !navigator.mediaDevices.getUserMedia){
      return typedFallback(title, onCode);
    }

    navigator.mediaDevices.getUserMedia({ video:{ facingMode:"environment" } }).then(function(stream){
      var video = document.createElement("video");
      video.srcObject = stream; video.setAttribute("playsinline","");
      video.style.cssText = "width:100%;max-height:70vh;object-fit:cover;border-radius:12px";

      var overlay = document.createElement("div");
      overlay.style.cssText = "position:fixed;inset:0;background:#000;z-index:2147483000;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:14px;padding:18px;box-sizing:border-box";

      var caption = document.createElement("div");
      caption.textContent = title;
      caption.style.cssText = "color:#fff;font:600 15px/1.3 system-ui,sans-serif;text-align:center";

      var row = document.createElement("div");
      row.style.cssText = "display:flex;gap:10px;flex-wrap:wrap;justify-content:center";

      var typeBtn = document.createElement("button");
      typeBtn.textContent = "Type code";
      typeBtn.style.cssText = "padding:10px 18px;border-radius:10px;border:1px solid #444;background:#111;color:#fff;font:600 14px system-ui;cursor:pointer";

      var stopBtn = document.createElement("button");
      stopBtn.textContent = "Cancel";
      stopBtn.style.cssText = "padding:10px 18px;border-radius:10px;border:1px solid #666;background:#222;color:#fff;font:600 14px system-ui;cursor:pointer";

      row.appendChild(typeBtn); row.appendChild(stopBtn);
      overlay.appendChild(caption); overlay.appendChild(video); overlay.appendChild(row);
      document.body.appendChild(overlay);

      var live = true;
      function stop(){
        if(!live) return;
        live = false;
        try{ stream.getTracks().forEach(function(t){ t.stop(); }); }catch(_){}
        if(overlay.parentNode) overlay.parentNode.removeChild(overlay);
      }
      stopBtn.addEventListener("click", stop);
      typeBtn.addEventListener("click", function(){ stop(); typedFallback(title, onCode); });

      video.play().then(function(){
        var det = new window.BarcodeDetector({ formats:["qr_code","code_128","ean_13","ean_8","code_39","upc_a","upc_e","itf"] });
        function tick(){
          if(!live) return;
          det.detect(video).then(function(codes){
            if(!live) return;
            if(codes && codes.length){
              var v = codes[0].rawValue;
              stop(); buzz(); onCode(String(v));
              return;
            }
            requestAnimationFrame(tick);
          }).catch(function(){ if(live) requestAnimationFrame(tick); });
        }
        tick();
      }).catch(function(){ stop(); typedFallback(title, onCode); });
    }).catch(function(){
      typedFallback(title, onCode);
    });
  }

  window.ProFixScan = { open: open };
})();
