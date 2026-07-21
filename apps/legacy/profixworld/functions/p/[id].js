// profixworld.com/p/<id> — WhatsApp-friendly product share links.
// Serves per-product OpenGraph tags (photo, name, price) so links unfurl
// beautifully in WhatsApp, then redirects humans to the store's product view.
// Deploys automatically with `wrangler pages deploy` (functions/ folder).

const SB_URL = "https://toxwbjofyglbyjanxmzv.supabase.co";
const SB_KEY = "sb_publishable_zlEDeh6lBwEvLuWJ5EUbNQ_Hr_pmKO0";

const esc = s => String(s || "").replace(/[&<>"']/g, c => (
  { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

export async function onRequest(context) {
  const id = context.params.id;
  if (!/^\d+$/.test(id)) return Response.redirect("https://profixworld.com/", 302);

  let p = null;
  try {
    const r = await fetch(
      `${SB_URL}/rest/v1/store_products?id=eq.${id}&select=id,name,brand,price,image_url,images,description,stock`,
      { headers: { apikey: SB_KEY, Authorization: `Bearer ${SB_KEY}` } });
    const rows = await r.json();
    p = rows && rows[0];
  } catch (e) {}

  if (!p) return Response.redirect("https://profixworld.com/", 302);

  const img = (p.images && p.images[0]) || p.image_url || "https://profixworld.com/partner-512.png";
  const title = `${p.name}${p.brand ? " · " + p.brand : ""} — ₹${Number(p.price).toLocaleString("en-IN")}`;
  const desc = (p.description || "2-hour doorstep delivery in Saravanampatti · COD & UPI · ProFix")
    .slice(0, 160);
  const target = `https://profixworld.com/#p=${p.id}`;

  const html = `<!DOCTYPE html>
<html lang="en"><head>
<meta charset="UTF-8">
<title>${esc(title)}</title>
<meta property="og:type" content="product">
<meta property="og:site_name" content="ProFix">
<meta property="og:title" content="${esc(title)}">
<meta property="og:description" content="${esc(desc)}">
<meta property="og:image" content="${esc(img)}">
<meta property="og:url" content="https://profixworld.com/p/${p.id}">
<meta name="twitter:card" content="summary_large_image">
<meta http-equiv="refresh" content="0;url=${esc(target)}">
</head><body>
<p>Opening ProFix… <a href="${esc(target)}">tap here if nothing happens</a>.</p>
<script>location.replace(${JSON.stringify(target)});</script>
</body></html>`;

  return new Response(html, {
    headers: { "content-type": "text/html; charset=utf-8", "cache-control": "public, max-age=300" }
  });
}
