/* ============================================================
   Systeme visuel commun a la presentation infographique.
   Palette, gabarits de diapositive et briques reutilisables.
   ============================================================ */
const React = require("react");
const { renderToStaticMarkup } = require("react-dom/server");
const sharp = require("sharp");

/* ── Palette : bleu dominant, orange en accent (paire validee CVD) ── */
const C = {
  bleu: "4444AD",
  bleufonce: "191970",
  bleunuit: "101038",
  orange: "D96F2B",
  or: "6E6ECB",
  teal: "2A2A80",
  encre: "1D2433",
  encre2: "4A5468",
  muet: "8A93A5",
  surface: "FFFFFF",
  carte: "F4F5FA",
  rose: "F7EAE4",
  bleupale: "E7E7F3",
  grispale: "E2E3EC",
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
  type: "outer", color: "13134F", opacity: op, blur: 10, offset: 2, angle: 90,
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
    x: 10.4, y: -1.5, w: 5.2, h: 5.2, fill: { color: "23236B" }, line: { type: "none" },
  });
  s.addShape(pres.ShapeType.ellipse, {
    x: -1.6, y: 4.8, w: 4.4, h: 4.4, fill: { color: "23236B" }, line: { type: "none" },
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
      fontFace: POLICE, fontSize: 14, color: "B7B7DB", lineSpacing: 18,
    });
  }
  return s;
}

/* ── Carte blanche a coins arrondis ── */
function carte(pres, s, x, y, w, h, teinte) {
  s.addShape(pres.ShapeType.roundRect, {
    x, y, w, h, rectRadius: 0.06,
    fill: { color: teinte || C.carte }, line: { type: "none" }, shadow: ombre(0.10),
  });
}

/* ── Pastille circulaire coloree portant une icone ── */
async function pastille(s, x, y, d, couleur, Icone) {
  const pres = s._pres || null;
  s.addShape("ellipse", {
    x, y, w: d, h: d,
    fill: { color: couleur }, line: { color: "FFFFFF", width: 2.5 }, shadow: ombre(0.18),
  });
  const t = d * 0.46;
  s.addImage({ data: await png(Icone, "FFFFFF", 320), x: x + (d - t) / 2, y: y + (d - t) / 2, w: t, h: t });
}

/* ── Grand nombre avec son libelle ── */
function stat(s, x, y, w, valeur, libelle, couleur, taille) {
  s.addText(valeur, {
    x, y, w, h: (taille || 40) / 72 + 0.16, margin: 0, align: "center", valign: "middle",
    fontFace: POLICE, fontSize: taille || 40, bold: true, color: couleur || C.bleufonce,
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
