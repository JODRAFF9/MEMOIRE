/* ============================================================
   Infographie de synthese du memoire, au format PowerPoint editable.
   Une diapositive 16:9 en trois colonnes, sur le modele fourni.
   Chiffres repris du rapport (EHCVM I et II, estimateur PSM-DD).
   Lancement : node infographie.js
   ============================================================ */
const pptxgen = require("pptxgenjs");
const { png } = require("./icones");
const { FaBaby, FaFaucet, FaBasketShopping, FaHandHoldingDollar } = require("react-icons/fa6");

/* ── Palette : bleu dominant, orange en accent (paire validee CVD) ── */
const BLEU = "41639E";
const BLEUFONCE = "1E2B4A";
const ORANGE = "D96F2B";
const OR = "C98A24";
const TEAL = "3E8C9A";
const ENCRE = "1D2433";
const ENCRE2 = "4A5468";
const MUET = "8A93A5";
const SURFACE = "FBFAF8";
const ROSE = "F7EAE4";
const BLEUPALE = "E5EEF4";

/* ── Reperes de mise en page (pouces) ── */
const BASE = 6.37;   // ligne de base des barres
const ECH = 0.190;   // pouce par point de pourcentage

async function main() {
  const pres = new pptxgen();
  pres.layout = "LAYOUT_WIDE"; // 13,33 x 7,5 pouces
  pres.author = "Sie Rachid TRAORE";
  pres.title = "Transferts de migrants et pauvrete infantile au Senegal";

  const s = pres.addSlide();
  s.background = { color: SURFACE };

  /* ── Aplats decoratifs ── */
  s.addShape(pres.ShapeType.ellipse, {
    x: -2.3, y: 3.5, w: 6.5, h: 4.6, fill: { color: ROSE }, line: { type: "none" },
  });
  s.addShape(pres.ShapeType.ellipse, {
    x: 9.7, y: 4.6, w: 6.0, h: 4.4, fill: { color: BLEUPALE }, line: { type: "none" },
  });
  s.addShape(pres.ShapeType.ellipse, {
    x: 12.0, y: -1.7, w: 3.2, h: 3.2, fill: { color: BLEUPALE }, line: { type: "none" },
  });

  /* ── Titre et chapeau ── */
  s.addText("Transferts de migrants et pauvreté infantile :\nle paradoxe sénégalais", {
    x: 0.5, y: 0.20, w: 12.33, h: 0.98, align: "center", margin: 0,
    fontFace: "Calibri", fontSize: 27, bold: true, color: BLEUFONCE, lineSpacing: 34,
  });
  s.addText(
    "Impact des transferts de fonds sur les 7 dimensions du bien-être de l'enfant, 2018-2022, sur 17 786 enfants suivis.\n" +
    "Sur cet horizon, les transferts n'ont pas réduit la pauvreté multidimensionnelle des enfants.",
    {
      x: 1.2, y: 1.24, w: 10.9, h: 0.52, align: "center", margin: 0,
      fontFace: "Calibri", fontSize: 12.5, color: ENCRE2, lineSpacing: 17,
    }
  );

  /* ── Intitules de colonnes ── */
  s.addText("Un impact paradoxal", {
    x: 0.45, y: 1.86, w: 8.3, h: 0.36, align: "center", margin: 0,
    fontFace: "Calibri", fontSize: 18, bold: true, color: BLEU,
  });
  s.addText("Recommandations stratégiques", {
    x: 8.95, y: 1.86, w: 3.95, h: 0.36, align: "center", margin: 0,
    fontFace: "Calibri", fontSize: 18, bold: true, color: BLEU,
  });

  /* ============================================================
     COLONNE GAUCHE
     ============================================================ */
  s.addText("+6,4", {
    x: 0.45, y: 2.26, w: 1.9, h: 0.82, align: "center", margin: 0, valign: "middle",
    fontFace: "Calibri", fontSize: 42, bold: true, color: BLEUFONCE,
  });
  s.addText("points d'écart défavorable,\nsignificatif à 5 %", {
    x: 0.45, y: 3.06, w: 1.9, h: 0.48, align: "center", margin: 0,
    fontFace: "Calibri", fontSize: 10.5, color: ENCRE2, lineSpacing: 14,
  });

  s.addShape(pres.ShapeType.rect, {
    x: 2.46, y: 2.32, w: 0.03, h: 1.16, fill: { color: ORANGE }, line: { type: "none" },
  });

  s.addText("La pauvreté a reculé près de trois fois moins vite chez les enfants des ménages bénéficiaires.", {
    x: 2.64, y: 2.26, w: 2.2, h: 1.3, margin: 0, valign: "top",
    fontFace: "Calibri", fontSize: 14, bold: true, color: ENCRE, lineSpacing: 19,
  });

  /* Barres dessinees : maitrise totale de la virgule decimale */
  s.addText("Recul de l'incidence MODA entre 2018 et 2021", {
    x: 0.45, y: 3.72, w: 4.4, h: 0.28, align: "center", margin: 0,
    fontFace: "Calibri", fontSize: 11.5, bold: true, color: ENCRE,
  });

  const barres = [
    { x: 1.50, val: 3.5, couleur: ORANGE, nom: "Bénéficiaires" },
    { x: 3.00, val: 9.9, couleur: BLEU, nom: "Témoins appariés" },
  ];
  barres.forEach((b) => {
    const h = b.val * ECH;
    s.addShape(pres.ShapeType.roundRect, {
      x: b.x, y: BASE - h, w: 0.85, h: h, rectRadius: 0.04,
      fill: { color: b.couleur }, line: { type: "none" },
    });
    s.addText(b.val.toFixed(1).replace(".", ",") + " pts", {
      x: b.x - 0.25, y: BASE - h - 0.34, w: 1.35, h: 0.3, align: "center", margin: 0,
      fontFace: "Calibri", fontSize: 14, bold: true, color: ENCRE,
    });
    s.addText(b.nom, {
      x: b.x - 0.3, y: BASE + 0.08, w: 1.45, h: 0.3, align: "center", margin: 0,
      fontFace: "Calibri", fontSize: 11.5, bold: true, color: ENCRE2,
    });
  });
  s.addShape(pres.ShapeType.rect, {
    x: 1.30, y: BASE, w: 3.3, h: 0.02, fill: { color: "CFD4DD" }, line: { type: "none" },
  });

  s.addText("L'écart de 6,4 points est l'effet estimé par appariement et double différence.", {
    x: 0.45, y: 6.72, w: 4.4, h: 0.34, align: "center", margin: 0,
    fontFace: "Calibri", fontSize: 10.5, color: ENCRE2, lineSpacing: 13,
  });

  /* ============================================================
     COLONNE CENTRALE
     ============================================================ */
  const ombre = () => ({ type: "outer", color: "1E2B4A", opacity: 0.18, blur: 8, offset: 2, angle: 90 });

  s.addShape(pres.ShapeType.ellipse, {
    x: 5.25, y: 2.26, w: 1.1, h: 1.1,
    fill: { color: ORANGE }, line: { color: "FFFFFF", width: 3 }, shadow: ombre(),
  });
  s.addImage({ data: await png(FaBaby, "FFFFFF", 320), x: 5.55, y: 2.56, w: 0.5, h: 0.5 });

  s.addText("La nutrition et les 0 à 4 ans en première ligne", {
    x: 6.50, y: 2.26, w: 2.25, h: 0.5, margin: 0, valign: "top",
    fontFace: "Calibri", fontSize: 13.5, bold: true, color: ENCRE, lineSpacing: 17,
  });
  s.addText("L'écart se concentre sur la nutrition (+6,8 points) et sur les 0 à 4 ans (+9,1 points).", {
    x: 6.50, y: 2.78, w: 2.25, h: 0.6, margin: 0, valign: "top",
    fontFace: "Calibri", fontSize: 10.5, color: ENCRE2, lineSpacing: 13.5,
  });

  s.addText("Incidence de la pauvreté multidimensionnelle (MODA)", {
    x: 5.05, y: 3.58, w: 3.8, h: 0.42, align: "center", margin: 0,
    fontFace: "Calibri", fontSize: 11.5, bold: true, color: ENCRE, lineSpacing: 15,
  });

  const anneaux = [
    { x: 5.85, val: 63.5, reste: 36.5, couleur: BLEU, fond: "DCE3EC", lib: "2018-19" },
    { x: 7.30, val: 57.8, reste: 42.2, couleur: ORANGE, fond: "F1E2D6", lib: "2021-22" },
  ];
  anneaux.forEach((a) => {
    s.addChart(
      pres.ChartType.doughnut,
      [{ name: a.lib, labels: ["Privés", "Non privés"], values: [a.val, a.reste] }],
      {
        x: a.x, y: 4.00, w: 1.25, h: 1.25,
        chartColors: [a.couleur, a.fond], holeSize: 60,
        showLegend: false, showTitle: false, showValue: false,
        plotArea: { fill: { color: SURFACE } }, chartArea: { fill: { color: SURFACE } },
      }
    );
    s.addText(a.val.toFixed(1).replace(".", ",") + " %\n" + a.lib, {
      x: a.x, y: 4.42, w: 1.25, h: 0.44, align: "center", margin: 0,
      fontFace: "Calibri", fontSize: 11.5, bold: true, color: BLEUFONCE, lineSpacing: 13.5,
    });
  });

  s.addText("Chez les 0 à 4 ans, l'incidence progresse au contraire de 56,9 % à 60,1 %.", {
    x: 5.15, y: 5.34, w: 3.6, h: 0.34, align: "center", margin: 0,
    fontFace: "Calibri", fontSize: 10.5, color: ENCRE2, lineSpacing: 13,
  });

  s.addShape(pres.ShapeType.ellipse, {
    x: 5.25, y: 5.80, w: 1.1, h: 1.1,
    fill: { color: OR }, line: { color: "FFFFFF", width: 3 }, shadow: ombre(),
  });
  s.addText("68 %", {
    x: 5.25, y: 6.14, w: 1.1, h: 0.42, align: "center", margin: 0,
    fontFace: "Calibri", fontSize: 19, bold: true, color: "FFFFFF",
  });

  s.addText("Des fonds affectés au soutien courant", {
    x: 6.50, y: 5.82, w: 2.25, h: 0.5, margin: 0, valign: "top",
    fontFace: "Calibri", fontSize: 13.5, bold: true, color: ENCRE, lineSpacing: 17,
  });
  s.addText("Moins d'un dixième des envois va à la santé ou à la scolarité.", {
    x: 6.50, y: 6.34, w: 2.25, h: 0.56, margin: 0, valign: "top",
    fontFace: "Calibri", fontSize: 10.5, color: ENCRE2, lineSpacing: 13.5,
  });

  /* ============================================================
     COLONNE DROITE
     ============================================================ */
  const recos = [
    {
      icone: await png(FaBasketShopping, "FFFFFF", 320), couleur: OR,
      titre: "Sécurité alimentaire et petite enfance",
      texte: "Filets sociaux, cantines et suivi nutritionnel en priorité dans les communes d'émigration.",
    },
    {
      icone: await png(FaFaucet, "FFFFFF", 320), couleur: BLEU,
      titre: "Compléter par l'offre publique de services",
      texte: "L'eau, l'assainissement et la santé relèvent d'investissements que le privé ne remplace pas.",
    },
    {
      icone: await png(FaHandHoldingDollar, "FFFFFF", 320), couleur: TEAL,
      titre: "Cibler les petits montants reçus",
      texte: "Accompagner les ménages qui reçoivent le moins et réduire les coûts des transferts formels.",
    },
  ];

  recos.forEach((r, i) => {
    const y = 2.26 + i * 1.64;
    s.addShape(pres.ShapeType.ellipse, {
      x: 8.95, y: y, w: 1.15, h: 1.15,
      fill: { color: r.couleur }, line: { color: "FFFFFF", width: 3 }, shadow: ombre(),
    });
    s.addImage({ data: r.icone, x: 9.26, y: y + 0.31, w: 0.53, h: 0.53 });
    s.addText(r.titre, {
      x: 10.30, y: y - 0.02, w: 2.6, h: 0.5, margin: 0, valign: "top",
      fontFace: "Calibri", fontSize: 13.5, bold: true, color: ENCRE, lineSpacing: 17,
    });
    s.addText(r.texte, {
      x: 10.30, y: y + 0.50, w: 2.6, h: 0.62, margin: 0, valign: "top",
      fontFace: "Calibri", fontSize: 10.5, color: ENCRE2, lineSpacing: 13.5,
    });
  });

  /* ── Pied ── */
  s.addText(
    "Source : calcul de l'auteur, EHCVM I (2018-2019) et EHCVM II (2021-2022), estimateur PSM-double différence.",
    { x: 0.45, y: 7.10, w: 7.6, h: 0.26, margin: 0,
      fontFace: "Calibri", fontSize: 9.5, color: MUET }
  );
  s.addText("Sié Rachid TRAORÉ · ENSAE · 2026", {
    x: 8.9, y: 7.10, w: 4.0, h: 0.26, align: "right", margin: 0,
    fontFace: "Calibri", fontSize: 9.5, color: MUET,
  });

  s.addNotes(
    "Infographie de synthese du memoire. Chiffres du dernier run de tout.do : ATT PSM-DD 0,064 " +
    "significatif a 5 % ; recul de l'incidence 3,5 points chez les beneficiaires contre 9,9 points " +
    "chez les temoins apparies, soit 6,4 points d'ecart ; nutrition +6,8 points ; 0-4 ans +9,1 points ; " +
    "incidence d'ensemble 63,5 % puis 57,8 % ; 0-4 ans 56,9 % puis 60,1 % ; 68,5 % des transferts " +
    "affectes au soutien courant en 2021-2022."
  );

  await pres.writeFile({ fileName: "infographie_memoire.pptx" });
  console.log(">>> infographie_memoire.pptx genere");
}

main().catch((e) => { console.error(e); process.exit(1); });
