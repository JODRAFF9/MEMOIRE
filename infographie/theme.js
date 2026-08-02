/* ============================================================
   Systeme visuel commun a la presentation infographique.
   Palette, gabarits de diapositive et briques reutilisables.
   ============================================================ */
const React = require("react");
const { renderToStaticMarkup } = require("react-dom/server");
const sharp = require("sharp");

/* ── Palette : bleu dominant, orange en accent (paire validee CVD) ── */
const C = {
  bleu: "41639E",
  bleufonce: "1E2B4A",
  bleunuit: "16213D",
  orange: "D96F2B",
  or: "C98A24",
  teal: "3E8C9A",
  encre: "1D2433",
  encre2: "4A5468",
  muet: "8A93A5",
  surface: "FFFFFF",
  carte: "F4F5FA",
  rose: "F7EAE4",
  bleupale: "E5EEF4",
  grispale: "E3E7EE",
};

const POLICE = "Calibri";

/* ── Icones react-icons rasterisees en PNG base64 ── */
const cache = new Map();
async function png(Icone, couleur, taille = 320) {
  const cle = Icone.name + couleur + taille;
  if (cache.has(cle)) return cache.get(cle);
  const svg = renderToStaticMarkup(React.createElement(Icone, { color: couleur, size: taille }));
  const buf = await sharp(Buffer.from(svg)).resize(taille, taille).png().toBuffer();
  const d = "image/png;base64," + buf.toString("base64");
  cache.set(cle, d);
  return d;
}

/* ── Ombre portee : objet neuf a chaque appel (pptxgenjs mute en place) ── */
const ombre = (op = 0.16) => ({
  type: "outer", color: "1E2B4A", opacity: op, blur: 10, offset: 2, angle: 90,
});

/* ── Diapositive de contenu : fond clair, titre, pied ── */
function slideContenu(pres, titre, chapeau) {
  const s = pres.addSlide();
  s.background = { color: C.surface };
  s.addText(titre, {
    x: 0.6, y: 0.38, w: 12.1, h: 0.58, margin: 0, valign: "middle",
    fontFace: POLICE, fontSize: 27, bold: true, color: C.bleufonce,
  });
  if (chapeau) {
    s.addText(chapeau, {
      x: 0.6, y: 0.98, w: 12.1, h: 0.52, margin: 0, valign: "top",
      fontFace: POLICE, fontSize: 13, color: C.encre2, lineSpacing: 17,
    });
  }
  return s;
}

/* ── Diapositive de section : fond sombre ── */
function slideSection(pres, numero, titre, resume) {
  const s = pres.addSlide();
  s.background = { color: C.bleunuit };
  s.addShape(pres.ShapeType.ellipse, {
    x: 10.4, y: -1.5, w: 5.2, h: 5.2, fill: { color: "24365E" }, line: { type: "none" },
  });
  s.addShape(pres.ShapeType.ellipse, {
    x: -1.6, y: 4.8, w: 4.4, h: 4.4, fill: { color: "24365E" }, line: { type: "none" },
  });
  s.addText(numero, {
    x: 1.1, y: 2.44, w: 1.4, h: 1.32, margin: 0, align: "left", valign: "middle",
    fontFace: POLICE, fontSize: 72, bold: true, color: C.orange,
  });
  s.addText(titre, {
    x: 2.6, y: 2.62, w: 9.5, h: 0.9, margin: 0, valign: "middle",
    fontFace: POLICE, fontSize: 34, bold: true, color: "FFFFFF",
  });
  if (resume) {
    s.addText(resume, {
      x: 2.65, y: 3.58, w: 9.0, h: 0.5, margin: 0, valign: "top",
      fontFace: POLICE, fontSize: 14, color: "AFC0DA", lineSpacing: 18,
    });
  }
  return s;
}

/* ── Carte blanche a coins arrondis ── */
function carte(pres, s, x, y, w, h, teinte) {
  if (!teinte) return; /* sans teinte explicite, on laisse respirer le fond blanc */
  s.addShape(pres.ShapeType.roundRect, {
    x, y, w, h, rectRadius: 0.06,
    fill: { color: teinte }, line: { type: "none" },
  });
}

/* ── Eclaircissement d'une teinte vers le blanc ── */
function eclaircir(hex, part) {
  const v = [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16));
  return v.map((c) => Math.round(c + (255 - c) * part).toString(16).padStart(2, "0")).join("").toUpperCase();
}

/* ── Pastille : icone saturee sur un disque de la meme teinte, eclairci ── */
async function pastille(s, x, y, d, couleur, Icone) {
  s.addShape("ellipse", {
    x, y, w: d, h: d,
    fill: { color: eclaircir(couleur, 0.84) },
    line: { color: eclaircir(couleur, 0.64), width: 1.25 },
    shadow: ombre(0.08),
  });
  const t = d * 0.46;
  s.addImage({ data: await png(Icone, couleur, 320), x: x + (d - t) / 2, y: y + (d - t) / 2, w: t, h: t });
}

/* ── Grand nombre avec son libelle ── */
function stat(s, x, y, w, valeur, libelle, couleur, taille) {
  s.addText(valeur, {
    x, y, w, h: (taille || 40) / 72 + 0.16, margin: 0, align: "center", valign: "middle",
    fontFace: POLICE, fontSize: taille || 40, bold: true, color: C.bleufonce,
  });
  s.addText(libelle, {
    x, y: y + (taille || 40) / 72 + 0.18, w, h: 0.42, margin: 0, align: "center",
    fontFace: POLICE, fontSize: 10.5, color: C.encre2, lineSpacing: 13.5,
  });
}

/* ── Pied de page commun ── */
function pied(s, texte, numero) {
  if (texte) {
    s.addText(texte, {
      x: 0.6, y: 7.06, w: 9.0, h: 0.26, margin: 0,
      fontFace: POLICE, fontSize: 9, color: C.muet,
    });
  }
  s.addText(String(numero), {
    x: 11.9, y: 7.06, w: 0.4, h: 0.26, margin: 0, align: "right",
    fontFace: POLICE, fontSize: 9.5, color: C.muet,
  });
  s.addImage({ path: "logos/logo_ensae_new.png", x: 12.45, y: 6.95, w: 0.42, h: 0.42 });
}

/* ── Virgule decimale garantie ── */
const vg = (x, d = 1) => x.toFixed(d).replace(".", ",");

module.exports = { C, POLICE, png, ombre, slideContenu, slideSection, carte, pastille, stat, pied, vg };
