/* ============================================================
   Presentation de soutenance, style infographique, PowerPoint editable.
   Impact des transferts de migrants sur la pauvrete multidimensionnelle
   des enfants au Senegal. Chiffres du rapport (EHCVM I et II, PSM-DD).
   Lancement : node presentation.js
   ============================================================ */
const pptxgen = require("pptxgenjs");
const T = require("./theme");
const { C, POLICE, png, ombre, slideContenu, slideSection, carte, pastille, stat, pied, vg } = T;
const I = require("react-icons/fa6");

const SRC = "Source : calcul de l'auteur, EHCVM I (2018-2019) et EHCVM II (2021-2022).";

async function main() {
  const p = new pptxgen();
  p.layout = "LAYOUT_WIDE";
  p.author = "Sie Rachid TRAORE";
  p.company = "ENSAE Pierre Ndiaye";
  p.title = "Transferts de migrants et pauvrete multidimensionnelle des enfants au Senegal";
  let n = 0;

  /* ============================================================
     1. Page de titre
     ============================================================ */
  {
    const s = p.addSlide();
    s.background = { color: C.bleunuit };
    s.addShape(p.ShapeType.ellipse, { x: 9.6, y: -2.2, w: 6.4, h: 6.4, fill: { color: "23236B" }, line: { type: "none" } });
    s.addShape(p.ShapeType.ellipse, { x: -2.4, y: 4.2, w: 5.6, h: 5.6, fill: { color: "23236B" }, line: { type: "none" } });

    s.addShape(p.ShapeType.roundRect, {
      x: 0.62, y: 0.45, w: 1.35, h: 1.35, rectRadius: 0.1,
      fill: { color: "FFFFFF" }, line: { type: "none" }, shadow: ombre(0.22),
    });
    s.addImage({ path: "logos/logo_ensae_new.png", x: 0.75, y: 0.58, w: 1.09, h: 1.09 });
    s.addShape(p.ShapeType.roundRect, {
      x: 11.36, y: 0.45, w: 1.35, h: 1.35, rectRadius: 0.1,
      fill: { color: "FFFFFF" }, line: { type: "none" }, shadow: ombre(0.22),
    });
    s.addImage({ path: "logos/logo_ansd.jpg", x: 11.49, y: 0.67, w: 1.09, h: 0.91 });

    s.addText("RÉPUBLIQUE DU SÉNÉGAL", {
      x: 0, y: 0.55, w: 13.33, h: 0.3, align: "center", margin: 0,
      fontFace: POLICE, fontSize: 12, bold: true, color: "8FA6CC", charSpacing: 2,
    });
    s.addText("École nationale de la statistique et de l'analyse économique Pierre Ndiaye", {
      x: 0, y: 0.88, w: 13.33, h: 0.3, align: "center", margin: 0,
      fontFace: POLICE, fontSize: 12.5, color: "B7B7DB",
    });

    s.addText("Impact des transferts de migrants sur la pauvreté\nmultidimensionnelle des enfants au Sénégal", {
      x: 1.1, y: 1.85, w: 11.13, h: 1.85, align: "center", margin: 0, valign: "middle",
      fontFace: POLICE, fontSize: 31, bold: true, color: "FFFFFF", lineSpacing: 42,
    });

    s.addText("Mémoire de fin d'études, ingénieur statisticien économiste", {
      x: 1.1, y: 3.75, w: 11.13, h: 0.34, align: "center", margin: 0,
      fontFace: POLICE, fontSize: 14, color: C.orange,
    });

    [
      { x: 2.5, t: "Présenté par", n: "Sié Rachid TRAORÉ", r: "Élève ingénieur statisticien économiste" },
      { x: 7.2, t: "Sous la direction de", n: "Mamadou Abdoulaye DIALLO", r: "Chercheur postdoctoral en économie appliquée" },
    ].forEach((b) => {
      s.addText(b.t, {
        x: b.x, y: 4.62, w: 3.7, h: 0.28, align: "center", margin: 0,
        fontFace: POLICE, fontSize: 11, color: "8FA6CC",
      });
      s.addText(b.n, {
        x: b.x, y: 4.90, w: 3.7, h: 0.32, align: "center", margin: 0,
        fontFace: POLICE, fontSize: 15, bold: true, color: "FFFFFF",
      });
      s.addText(b.r, {
        x: b.x - 0.2, y: 5.24, w: 4.1, h: 0.4, align: "center", margin: 0,
        fontFace: POLICE, fontSize: 10.5, color: "B7B7DB", lineSpacing: 13,
      });
    });

    s.addText("Août 2026", {
      x: 0, y: 6.35, w: 13.33, h: 0.32, align: "center", margin: 0,
      fontFace: POLICE, fontSize: 13, color: "8FA6CC",
    });
    n++;
  }

  /* ============================================================
     2. Plan
     ============================================================ */
  {
    const s = slideContenu(p, "Plan de la présentation");
    const items = [
      { ic: I.FaChartLine, t: "Contexte et problématique", d: "Deux réalités qui se rejoignent", c: C.bleu },
      { ic: I.FaBookOpen, t: "Revue de la littérature", d: "Canaux, mesure et lacune", c: C.orange },
      { ic: I.FaScaleBalanced, t: "Cadre méthodologique", d: "MODA et identification PSM-DD", c: C.teal },
      { ic: I.FaMagnifyingGlass, t: "Résultats empiriques", d: "Effet, dimensions, montants", c: C.or },
      { ic: I.FaShieldHalved, t: "Robustesse et discussion", d: "Ce qui tient et ce qui ne tient pas", c: C.bleu },
      { ic: I.FaLightbulb, t: "Conclusion et recommandations", d: "Ce qu'il faut en faire", c: C.orange },
    ];
    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      const x = 0.75 + (i % 3) * 4.15;
      const y = 1.72 + Math.floor(i / 3) * 2.55;
      carte(p, s, x, y, 3.75, 2.15);
      await pastille(s, x + 0.32, y + 0.34, 0.92, it.c, it.ic);
      s.addText(String(i + 1), {
        x: x + 2.85, y: y + 0.24, w: 0.65, h: 0.5, align: "right", margin: 0,
        fontFace: POLICE, fontSize: 30, bold: true, color: C.grispale,
      });
      s.addText(it.t, {
        x: x + 0.32, y: y + 1.36, w: 3.15, h: 0.34, margin: 0,
        fontFace: POLICE, fontSize: 14.5, bold: true, color: C.encre,
      });
      s.addText(it.d, {
        x: x + 0.32, y: y + 1.70, w: 3.15, h: 0.3, margin: 0,
        fontFace: POLICE, fontSize: 11, color: C.encre2,
      });
    }
    pied(s, null, ++n);
  }

  /* ============================================================
     3. Section 1
     ============================================================ */
  { slideSection(p, "01", "Contexte et problématique", "Une ressource privée massive, des privations infantiles persistantes."); n++; }

  /* ============================================================
     4. Contexte : les deux réalités
     ============================================================ */
  {
    const s = slideContenu(p, "Deux réalités qui se rejoignent");
    // Bloc gauche : les transferts
    carte(p, s, 0.7, 1.42, 5.85, 4.9);
    await pastille(s, 1.05, 1.75, 0.95, C.bleu, I.FaMoneyBillTransfer);
    s.addText("Une ressource extérieure de premier plan", {
      x: 2.22, y: 1.82, w: 4.05, h: 0.6, margin: 0, valign: "middle",
      fontFace: POLICE, fontSize: 16, bold: true, color: C.encre, lineSpacing: 20,
    });
    stat(s, 1.0, 2.95, 2.5, "2 220", "millions de dollars reçus en 2017,\ncontre 233 en 2000", C.bleu, 34);
    stat(s, 3.7, 2.95, 2.5, "12,1 %", "du produit intérieur brut,\n4ᵉ récepteur subsaharien", C.bleu, 34);
    s.addText(
      "À l'échelle des ménages, les montants reçus avoisinent le seuil de pauvreté monétaire annuel par tête.",
      { x: 1.0, y: 4.55, w: 5.25, h: 0.6, margin: 0, valign: "top",
        fontFace: POLICE, fontSize: 12.5, color: C.encre2, lineSpacing: 17 }
    );
    s.addText("Source : ANSD et OIM, profil migratoire 2018.", {
      x: 1.0, y: 5.85, w: 5.25, h: 0.26, margin: 0, fontFace: POLICE, fontSize: 9.5, color: C.muet,
    });

    // Bloc droit : les privations
    carte(p, s, 6.85, 1.42, 5.78, 4.9);
    await pastille(s, 7.2, 1.75, 0.95, C.orange, I.FaChildren);
    s.addText("Des privations infantiles d'ampleur", {
      x: 8.37, y: 1.82, w: 3.95, h: 0.6, margin: 0, valign: "middle",
      fontFace: POLICE, fontSize: 16, bold: true, color: C.encre, lineSpacing: 20,
    });
    stat(s, 7.15, 2.95, 2.5, "50,7 %", "des enfants de 0 à 17 ans privés\ndans au moins 4 des 7 domaines", C.orange, 34);
    stat(s, 9.85, 2.95, 2.5, "7", "domaines du bien-être,\nde l'eau à l'éducation", C.orange, 34);
    s.addText(
      "Ces manques échappent aux mesures fondées sur le seul revenu : un enfant peut vivre au-dessus du seuil monétaire et rester déscolarisé.",
      { x: 7.15, y: 4.55, w: 5.2, h: 0.75, margin: 0, valign: "top",
        fontFace: POLICE, fontSize: 12.5, color: C.encre2, lineSpacing: 17 }
    );
    s.addText("Source : ANSD et UNICEF, 2024.", {
      x: 7.15, y: 5.85, w: 5.2, h: 0.26, margin: 0, fontFace: POLICE, fontSize: 9.5, color: C.muet,
    });
    pied(s, null, ++n);
  }

  /* ============================================================
     5. Problématique
     ============================================================ */
  {
    const s = slideContenu(p, "Problématique");
    carte(p, s, 1.5, 1.55, 10.33, 1.62, C.bleufonce);
    s.addText("Dans quelle mesure les transferts de migrants réduisent-ils\nla pauvreté multidimensionnelle des enfants au Sénégal ?", {
      x: 1.8, y: 1.72, w: 9.73, h: 1.28, align: "center", margin: 0, valign: "middle",
      fontFace: POLICE, fontSize: 21, bold: true, color: "FFFFFF", lineSpacing: 31,
    });

    const blocs = [
      { ic: I.FaCircleQuestion, c: C.orange, t: "Une réponse qui n'a rien d'évident",
        d: "Les transferts desserrent la contrainte budgétaire, sans qu'un supplément de ressources se traduise mécaniquement par un recul des privations." },
      { ic: I.FaTriangleExclamation, c: C.or, t: "Un enjeu d'identification",
        d: "Recevoir des transferts suppose un réseau migratoire : les ménages bénéficiaires diffèrent des autres avant même le premier franc reçu." },
      { ic: I.FaBookOpen, c: C.teal, t: "Une lacune dans la littérature",
        d: "Aucune étude recensée ne combine mesure multidimensionnelle de la pauvreté infantile et identification sur panel en Afrique de l'Ouest." },
    ];
    blocs.forEach(async (b, i) => {
      const x = 0.7 + i * 4.15;
      carte(p, s, x, 3.45, 3.78, 2.95);
      s.addText(b.t, {
        x: x + 1.35, y: 3.72, w: 2.25, h: 0.72, margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 14, bold: true, color: C.encre, lineSpacing: 18,
      });
      s.addText(b.d, {
        x: x + 0.3, y: 4.6, w: 3.2, h: 1.6, margin: 0, valign: "top",
        fontFace: POLICE, fontSize: 12, color: C.encre2, lineSpacing: 16.5,
      });
    });
    for (let i = 0; i < blocs.length; i++) {
      await pastille(s, 0.7 + i * 4.15 + 0.3, 3.75, 0.9, blocs[i].c, blocs[i].ic);
    }
    pied(s, null, ++n);
  }

  /* ============================================================
     6. Objectifs et hypothèses
     ============================================================ */
  {
    const s = slideContenu(p, "Objectifs et hypothèses");
    carte(p, s, 0.7, 1.42, 5.85, 4.9);
    await pastille(s, 1.05, 1.75, 0.9, C.bleu, I.FaBullseye);
    s.addText("Objectifs", {
      x: 2.15, y: 1.82, w: 4.1, h: 0.5, margin: 0, valign: "middle",
      fontFace: POLICE, fontSize: 18, bold: true, color: C.encre,
    });
    s.addText("Évaluer l'impact des transferts de migrants sur la pauvreté multidimensionnelle des enfants au Sénégal.", {
      x: 1.05, y: 2.9, w: 5.2, h: 0.75, margin: 0, valign: "top",
      fontFace: POLICE, fontSize: 13.5, bold: true, color: C.encre, lineSpacing: 18,
    });
    ["Construire un indice de pauvreté multidimensionnelle adapté aux enfants sénégalais.",
     "Estimer l'impact des transferts sur cet indice et en analyser l'hétérogénéité."].forEach((t, i) => {
      s.addShape(p.ShapeType.ellipse, {
        x: 1.05, y: 3.85 + i * 1.12, w: 0.36, h: 0.36, fill: { color: C.bleu }, line: { type: "none" },
      });
      s.addText(String(i + 1), {
        x: 1.05, y: 3.87 + i * 1.12, w: 0.36, h: 0.32, align: "center", margin: 0,
        fontFace: POLICE, fontSize: 13, bold: true, color: "FFFFFF",
      });
      s.addText(t, {
        x: 1.58, y: 3.82 + i * 1.12, w: 4.65, h: 0.85, margin: 0, valign: "top",
        fontFace: POLICE, fontSize: 12.5, color: C.encre2, lineSpacing: 17,
      });
    });

    carte(p, s, 6.85, 1.42, 5.78, 4.9);
    await pastille(s, 7.2, 1.75, 0.9, C.orange, I.FaClipboardQuestion);
    s.addText("Hypothèses", {
      x: 8.3, y: 1.82, w: 4.0, h: 0.5, margin: 0, valign: "middle",
      fontFace: POLICE, fontSize: 18, bold: true, color: C.encre,
    });
    [
      { h: "H1", t: "Les transferts de migrants réduisent significativement la pauvreté multidimensionnelle des enfants." },
      { h: "H2", t: "Leur impact est hétérogène selon les dimensions, le milieu, le genre du chef de ménage, l'âge de l'enfant et le montant reçu." },
    ].forEach((b, i) => {
      const y = 2.9 + i * 1.72;
      carte(p, s, 7.15, y, 5.2, 1.5, C.bleupale);
      s.addText(b.h, {
        x: 7.4, y: y + 0.25, w: 0.75, h: 0.45, margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 22, bold: true, color: C.orange,
      });
      s.addText(b.t, {
        x: 8.2, y: y + 0.2, w: 3.95, h: 1.15, margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 12, color: C.encre, lineSpacing: 16.5,
      });
    });
    pied(s, null, ++n);
  }

  /* ============================================================
     7. Section 2 : revue
     ============================================================ */
  { slideSection(p, "02", "Revue de la littérature", "Trois enseignements : la sélection, la diversité des canaux, la lacune à combler."); n++; }

  /* ============================================================
     8. Canaux et effets documentés
     ============================================================ */
  {
    const s = slideContenu(p, "Pourquoi les migrants transfèrent, et avec quels effets");
    carte(p, s, 0.7, 1.42, 5.85, 4.9);
    s.addText("Trois familles de motivations", {
      x: 1.05, y: 1.72, w: 5.2, h: 0.42, margin: 0,
      fontFace: POLICE, fontSize: 17, bold: true, color: C.encre,
    });
    [
      { t: "Altruisme", d: "Les transferts décroissent avec le revenu du receveur.", r: "Lucas & Stark, 1985" },
      { t: "Intérêt personnel et échange", d: "Préserver un héritage, rembourser la dette du départ.", r: "Rapoport & Docquier, 2006" },
      { t: "Diversification du risque", d: "Les transferts assurent le ménage contre les chocs.", r: "Stark & Bloom, 1985" },
    ].forEach((b, i) => {
      const y = 2.32 + i * 1.32;
      s.addShape(p.ShapeType.ellipse, {
        x: 1.05, y: y + 0.08, w: 0.3, h: 0.3, fill: { color: C.bleu }, line: { type: "none" },
      });
      s.addText(b.t, {
        x: 1.55, y: y, w: 4.7, h: 0.32, margin: 0,
        fontFace: POLICE, fontSize: 14, bold: true, color: C.encre,
      });
      s.addText(b.d, {
        x: 1.55, y: y + 0.34, w: 4.7, h: 0.36, margin: 0,
        fontFace: POLICE, fontSize: 12, color: C.encre2, lineSpacing: 16,
      });
      s.addText(b.r, {
        x: 1.55, y: y + 0.72, w: 4.7, h: 0.26, margin: 0,
        fontFace: POLICE, fontSize: 10.5, italic: true, color: C.muet,
      });
    });

    carte(p, s, 6.85, 1.42, 5.78, 4.9);
    s.addText("Ce que la littérature empirique établit", {
      x: 7.2, y: 1.72, w: 5.15, h: 0.42, margin: 0,
      fontFace: POLICE, fontSize: 17, bold: true, color: C.encre,
    });
    [
      { ic: I.FaMoneyBillTransfer, c: C.bleu, t: "Pauvreté monétaire",
        d: "Recul modeste, atténué par les coûts.", r: "Azam & Gubert, 2006 ; Combes & Ebeke, 2011" },
      { ic: I.FaGraduationCap, c: C.or, t: "Éducation",
        d: "Scolarisation et capital humain en hausse.", r: "Cox Edwards & Ureta, 2003 ; Yang, 2008" },
      { ic: I.FaUtensils, c: C.orange, t: "Nutrition",
        d: "Effets fragiles, liés au maintien du lien.", r: "Davis & Brazil, 2016" },
    ].forEach((b, i) => {
      const y = 2.32 + i * 1.32;
      s.addText(b.t, {
        x: 8.35, y: y, w: 4.0, h: 0.32, margin: 0,
        fontFace: POLICE, fontSize: 14, bold: true, color: C.encre,
      });
      s.addText(b.d, {
        x: 8.35, y: y + 0.34, w: 4.0, h: 0.36, margin: 0,
        fontFace: POLICE, fontSize: 12, color: C.encre2, lineSpacing: 16,
      });
      s.addText(b.r, {
        x: 8.35, y: y + 0.72, w: 4.0, h: 0.26, margin: 0,
        fontFace: POLICE, fontSize: 10.5, italic: true, color: C.muet,
      });
    });
    for (let i = 0; i < 3; i++) {
      const ics = [I.FaMoneyBillTransfer, I.FaGraduationCap, I.FaUtensils];
      const cs = [C.bleu, C.or, C.orange];
      await pastille(s, 7.2, 2.32 + i * 1.32 + 0.06, 0.82, cs[i], ics[i]);
    }
    pied(s, null, ++n);
  }

  /* ============================================================
     9. Section 3 : méthodologie
     ============================================================ */
  { slideSection(p, "03", "Cadre méthodologique", "Mesurer la pauvreté par l'approche MODA, identifier l'effet par PSM et double différence."); n++; }

  /* ============================================================
     10. L'indice MODA
     ============================================================ */
  {
    const s = slideContenu(p, "Mesurer la pauvreté de l'enfant, l'approche MODA",
      "Sept dimensions, 14 indicateurs, trois groupes d'âge. Un enfant est pauvre s'il est privé dans au moins quatre dimensions.");
    const dims = [
      { ic: I.FaToilet, t: "Assainissement", c: C.bleu },
      { ic: I.FaDroplet, t: "Eau", c: C.teal },
      { ic: I.FaHouse, t: "Logement", c: C.bleu },
      { ic: I.FaUtensils, t: "Nutrition", c: C.orange },
      { ic: I.FaHeartPulse, t: "Santé", c: C.or },
      { ic: I.FaShieldHalved, t: "Protection", c: C.teal },
      { ic: I.FaGraduationCap, t: "Éducation", c: C.bleu },
    ];
    for (let i = 0; i < dims.length; i++) {
      const x = 0.72 + i * 1.71;
      carte(p, s, x, 1.95, 1.62, 1.95);
      await pastille(s, x + 0.36, 2.2, 0.9, dims[i].c, dims[i].ic);
      s.addText(dims[i].t, {
        x: x + 0.05, y: 3.24, w: 1.52, h: 0.42, align: "center", margin: 0, valign: "top",
        fontFace: POLICE, fontSize: 11.5, bold: true, color: C.encre, lineSpacing: 14,
      });
    }

    carte(p, s, 0.72, 4.22, 6.0, 2.15);
    s.addText("Deux seuils, comme le veut l'approche", {
      x: 1.05, y: 4.45, w: 5.4, h: 0.34, margin: 0,
      fontFace: POLICE, fontSize: 14.5, bold: true, color: C.encre,
    });
    s.addText(
      "Intra-dimension, l'enfant est privé s'il l'est dans au moins un indicateur de la dimension.\n" +
      "Inter-dimensions, il est pauvre s'il cumule au moins quatre des sept dimensions.",
      { x: 1.05, y: 4.85, w: 5.4, h: 1.1, margin: 0, valign: "top",
        fontFace: POLICE, fontSize: 12, color: C.encre2, lineSpacing: 17 }
    );

    carte(p, s, 6.95, 4.22, 5.68, 2.15);
    s.addText("Des indicateurs adaptés à l'âge", {
      x: 7.28, y: 4.45, w: 5.05, h: 0.34, margin: 0,
      fontFace: POLICE, fontSize: 14.5, bold: true, color: C.encre,
    });
    [["0 à 4 ans", "11 indicateurs"], ["5 à 14 ans", "13 indicateurs"], ["15 à 17 ans", "11 indicateurs"]]
      .forEach((g, i) => {
        const x = 7.28 + i * 1.72;
        s.addText(g[0], {
          x, y: 4.9, w: 1.6, h: 0.3, align: "center", margin: 0,
          fontFace: POLICE, fontSize: 12.5, bold: true, color: C.orange,
        });
        s.addText(g[1], {
          x, y: 5.22, w: 1.6, h: 0.3, align: "center", margin: 0,
          fontFace: POLICE, fontSize: 11.5, color: C.encre2,
        });
      });
    s.addText("L'illettrisme remplace chez les adolescents les indicateurs propres aux 0 à 4 ans.", {
      x: 7.28, y: 5.62, w: 5.05, h: 0.5, margin: 0, valign: "top",
      fontFace: POLICE, fontSize: 11, color: C.encre2, lineSpacing: 15,
    });
    pied(s, "Matrice complète des indicateurs et des seuils en annexe du mémoire.", ++n);
  }

  /* ============================================================
     11. Données et traitement
     ============================================================ */
  {
    const s = slideContenu(p, "Données et définition du traitement",
      "Deux vagues de l'EHCVM, un panel d'enfants suivis individuellement d'une vague à l'autre.");

    const chiffres = [
      { v: "6 127", l: "ménages enquêtés\naux deux vagues", c: C.bleu },
      { v: "17 786", l: "enfants suivis\nindividuellement", c: C.bleu },
      { v: "2 638", l: "enfants d'un ménage\nbénéficiaire en 2018", c: C.orange },
      { v: "14,8 %", l: "part des enfants\ntraités", c: C.orange },
    ];
    chiffres.forEach((ch, i) => {
      const x = 0.72 + i * 3.01;
      carte(p, s, x, 1.85, 2.85, 1.75);
      stat(s, x, 2.05, 2.85, ch.v, ch.l, ch.c, 32);
    });

    carte(p, s, 0.72, 3.85, 5.9, 2.5);
    await pastille(s, 1.05, 4.15, 0.85, C.teal, I.FaUsers);
    s.addText("Qui est traité ?", {
      x: 2.1, y: 4.2, w: 4.3, h: 0.4, margin: 0, valign: "middle",
      fontFace: POLICE, fontSize: 15, bold: true, color: C.encre,
    });
    s.addText(
      "L'enfant dont le ménage a reçu, en 2018, un transfert d'un expéditeur résidant hors du Sénégal et ayant déjà vécu dans le ménage. " +
      "Le statut est figé à la période de base : il ne peut pas être affecté par l'évolution ultérieure des privations.",
      { x: 1.05, y: 5.15, w: 5.25, h: 1.05, margin: 0, valign: "top",
        fontFace: POLICE, fontSize: 12, color: C.encre2, lineSpacing: 16.5 }
    );

    carte(p, s, 6.85, 3.85, 5.78, 2.5);
    await pastille(s, 7.18, 4.15, 0.85, C.or, I.FaMoneyBillTransfer);
    s.addText("À quoi servent les fonds reçus ?", {
      x: 8.23, y: 4.2, w: 4.15, h: 0.4, margin: 0, valign: "middle",
      fontFace: POLICE, fontSize: 15, bold: true, color: C.encre,
    });
    const motifs = [["Soutien courant", 68.5], ["Fêtes et évènements", 9.3], ["Santé", 6.5], ["Scolarité", 3.7]];
    motifs.forEach((m, i) => {
      const y = 5.13 + i * 0.30;
      s.addText(m[0], {
        x: 7.18, y, w: 1.85, h: 0.26, margin: 0,
        fontFace: POLICE, fontSize: 11, color: C.encre2,
      });
      s.addShape(p.ShapeType.roundRect, {
        x: 9.12, y: y + 0.05, w: (m[1] / 68.5) * 2.55, h: 0.16, rectRadius: 0.02,
        fill: { color: i === 0 ? C.or : C.grispale }, line: { type: "none" },
      });
      s.addText(vg(m[1]) + " %", {
        x: 11.78, y, w: 0.62, h: 0.26, align: "right", margin: 0,
        fontFace: POLICE, fontSize: 11, bold: true, color: C.encre,
      });
    });
    pied(s, SRC, ++n);
  }

  /* ============================================================
     12. Stratégie d'identification
     ============================================================ */
  {
    const s = slideContenu(p, "Stratégie d'identification",
      "Les ménages bénéficiaires diffèrent des autres : une comparaison directe attribuerait aux transferts des écarts préexistants.");

    const etapes = [
      { n: "1", ic: I.FaMagnifyingGlass, c: C.bleu, t: "Score de propension",
        d: "Un logit estime, pour chaque enfant, la probabilité de vivre dans un ménage bénéficiaire, à partir des caractéristiques du ménage à la période de base." },
      { n: "2", ic: I.FaUsers, c: C.teal, t: "Appariement",
        d: "Chaque enfant traité est comparé à des enfants témoins de score voisin, donc de genre, d'âge et de profil de ménage comparables." },
      { n: "3", ic: I.FaScaleBalanced, c: C.orange, t: "Double différence",
        d: "L'écart de trajectoire entre 2018 et 2021 élimine ce qui, dans les différences restantes, est inobservable mais stable dans le temps." },
    ];
    for (let i = 0; i < etapes.length; i++) {
      const e = etapes[i];
      const x = 0.72 + i * 4.15;
      carte(p, s, x, 1.85, 3.78, 3.4);
      await pastille(s, x + 0.3, 2.15, 0.88, e.c, e.ic);
      s.addText(e.n, {
        x: x + 2.85, y: 2.04, w: 0.65, h: 0.64, align: "right", margin: 0,
        fontFace: POLICE, fontSize: 34, bold: true, color: C.grispale,
      });
      s.addText(e.t, {
        x: x + 0.3, y: 3.18, w: 3.2, h: 0.34, margin: 0,
        fontFace: POLICE, fontSize: 15, bold: true, color: C.encre,
      });
      s.addText(e.d, {
        x: x + 0.3, y: 3.56, w: 3.2, h: 1.5, margin: 0, valign: "top",
        fontFace: POLICE, fontSize: 11.5, color: C.encre2, lineSpacing: 16,
      });
    }

    carte(p, s, 0.72, 5.48, 11.91, 0.95, C.bleufonce);
    s.addText(
      "L'estimateur retenu, PSM-double différence (Heckman et al., 1997, 1998), corrige simultanément la sélection sur les caractéristiques observables et les effets fixes inobservables.",
      { x: 1.1, y: 5.6, w: 11.15, h: 0.72, margin: 0, valign: "middle", align: "center",
        fontFace: POLICE, fontSize: 13, color: "FFFFFF", lineSpacing: 18 }
    );
    pied(s, null, ++n);
  }

  /* ============================================================
     13. Section 4 : résultats
     ============================================================ */
  { slideSection(p, "04", "Résultats empiriques", "Un effet qui ne va pas dans le sens attendu, et qui se localise précisément."); n++; }

  /* ============================================================
     14. État des lieux
     ============================================================ */
  {
    const s = slideContenu(p, "État de la pauvreté multidimensionnelle des enfants",
      "L'incidence recule entre les deux vagues, mais l'intensité reste stable : les enfants pauvres cumulent toujours près de cinq privations sur sept.");

    carte(p, s, 0.72, 1.95, 5.9, 4.4);
    s.addText("Indice MODA aux deux vagues", {
      x: 1.05, y: 2.2, w: 5.25, h: 0.36, margin: 0,
      fontFace: POLICE, fontSize: 15, bold: true, color: C.encre,
    });
    const lignes = [
      ["Incidence", "63,5 %", "57,8 %", "-5,7 pts"],
      ["Intensité", "70,7 %", "70,3 %", "-0,4 pt"],
      ["Indice ajusté", "0,449", "0,406", "-0,043"],
    ];
    ["", "2018-19", "2021-22", "Écart"].forEach((h, j) => {
      s.addText(h, {
        x: 1.05 + [0, 1.9, 3.15, 4.4][j], y: 2.72, w: [1.85, 1.2, 1.2, 1.2][j], h: 0.3,
        align: j === 0 ? "left" : "center", margin: 0,
        fontFace: POLICE, fontSize: 11, bold: true, color: C.muet,
      });
    });
    lignes.forEach((l, i) => {
      const y = 3.12 + i * 0.72;
      s.addShape(p.ShapeType.rect, {
        x: 1.05, y: y + 0.5, w: 5.25, h: 0.012, fill: { color: C.grispale }, line: { type: "none" },
      });
      l.forEach((cell, j) => {
        s.addText(cell, {
          x: 1.05 + [0, 1.9, 3.15, 4.4][j], y, w: [1.85, 1.2, 1.2, 1.2][j], h: 0.42,
          align: j === 0 ? "left" : "center", margin: 0, valign: "middle",
          fontFace: POLICE, fontSize: j === 0 ? 12.5 : 15,
          bold: j !== 0, color: j === 3 ? C.orange : (j === 0 ? C.encre2 : C.bleufonce),
        });
      });
    });
    s.addText("Enfants de 0 à 17 ans suivis aux deux vagues, seuil de quatre dimensions.", {
      x: 1.05, y: 5.55, w: 5.25, h: 0.5, margin: 0, valign: "top",
      fontFace: POLICE, fontSize: 11, color: C.encre2, lineSpacing: 15,
    });

    carte(p, s, 6.85, 1.95, 5.78, 4.4);
    s.addText("Incidence selon le statut du ménage", {
      x: 7.18, y: 2.2, w: 5.15, h: 0.36, margin: 0,
      fontFace: POLICE, fontSize: 15, bold: true, color: C.encre,
    });
    const grp = [
      { t: "Non-bénéficiaires", v: [66.6, 60.5], c: C.bleu },
      { t: "Bénéficiaires", v: [46.2, 42.5], c: C.orange },
    ];
    grp.forEach((g, i) => {
      const y = 2.85 + i * 1.55;
      s.addText(g.t, {
        x: 7.18, y, w: 2.5, h: 0.3, margin: 0,
        fontFace: POLICE, fontSize: 12.5, bold: true, color: C.encre,
      });
      g.v.forEach((val, j) => {
        const yy = y + 0.38 + j * 0.42;
        s.addText(j === 0 ? "2018-19" : "2021-22", {
          x: 7.18, y: yy, w: 0.95, h: 0.28, margin: 0,
          fontFace: POLICE, fontSize: 10.5, color: C.muet,
        });
        s.addShape(p.ShapeType.roundRect, {
          x: 8.2, y: yy + 0.05, w: (val / 70) * 3.1, h: 0.2, rectRadius: 0.02,
          fill: { color: j === 0 ? g.c : g.c }, line: { type: "none" },
          transparency: j === 0 ? 0 : 35,
        });
        s.addText(vg(val) + " %", {
          x: 11.62, y: yy, w: 0.78, h: 0.28, align: "right", margin: 0,
          fontFace: POLICE, fontSize: 11.5, bold: true, color: C.encre,
        });
      });
    });
    s.addText("Les enfants de ménages bénéficiaires partent d'un niveau plus favorable : cet avantage précède le traitement.", {
      x: 7.18, y: 5.5, w: 5.15, h: 0.6, margin: 0, valign: "top",
      fontFace: POLICE, fontSize: 11, color: C.encre2, lineSpacing: 15,
    });
    pied(s, SRC, ++n);
  }

  /* ============================================================
     15. Qualité de l'appariement
     ============================================================ */
  {
    const s = slideContenu(p, "Qualité de l'appariement",
      "Après appariement, les enfants traités et leurs témoins ne se distinguent plus sur les caractéristiques observables.");

    const kpis = [
      { v: "11,4 %", l: "différence standardisée\nmoyenne avant appariement", c: C.muet },
      { v: "2,4 %", l: "après appariement,\nbien sous le seuil de 10 %", c: C.teal },
      { v: "16 210", l: "observations-enfants\nsur le support commun", c: C.bleu },
      { v: "0,150", l: "pseudo-R² du logit,\nsur 17 735 enfants", c: C.bleu },
    ];
    kpis.forEach((k, i) => {
      const x = 0.72 + i * 3.01;
      carte(p, s, x, 1.9, 2.85, 1.8);
      stat(s, x, 2.12, 2.85, k.v, k.l, k.c, 30);
    });

    carte(p, s, 0.72, 3.95, 11.91, 2.4);
    s.addText("Équilibre des principales covariables, différence standardisée en %", {
      x: 1.05, y: 4.18, w: 11.25, h: 0.34, margin: 0,
      fontFace: POLICE, fontSize: 14, bold: true, color: C.encre,
    });
    const cov = [
      ["Taille du ménage", 49.7, 19.4], ["Dépense par tête", 29.3, 20.2],
      ["Milieu rural", 22.2, 8.9], ["Genre du chef", 27.5, 9.0],
      ["Genre de l'enfant", 0.6, 2.7], ["Âge de l'enfant", 2.0, 2.5],
    ];
    cov.forEach((c0, i) => {
      const x = 1.05 + (i % 3) * 3.8;
      const y = 4.68 + Math.floor(i / 3) * 0.78;
      s.addText(c0[0], {
        x, y, w: 1.75, h: 0.28, margin: 0,
        fontFace: POLICE, fontSize: 11, color: C.encre2,
      });
      s.addShape(p.ShapeType.roundRect, {
        x, y: y + 0.3, w: Math.max(0.04, (c0[1] / 50) * 1.55), h: 0.14, rectRadius: 0.02,
        fill: { color: C.grispale }, line: { type: "none" },
      });
      s.addShape(p.ShapeType.roundRect, {
        x, y: y + 0.48, w: Math.max(0.04, (c0[2] / 50) * 1.55), h: 0.14, rectRadius: 0.02,
        fill: { color: C.teal }, line: { type: "none" },
      });
      s.addText(vg(c0[1]) + "  →  " + vg(c0[2]), {
        x: x + 1.8, y: y + 0.28, w: 1.5, h: 0.36, margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 11, bold: true, color: C.encre,
      });
    });
    pied(s, "Gris : avant appariement ; vert : après appariement. " + SRC, ++n);
  }

  /* ============================================================
     16. Résultat principal
     ============================================================ */
  {
    const s = slideContenu(p, "Le résultat central");

    carte(p, s, 0.72, 1.42, 3.6, 4.95, C.bleufonce);
    s.addText("+6,4", {
      x: 0.9, y: 2.25, w: 3.24, h: 1.1, align: "center", margin: 0, valign: "middle",
      fontFace: POLICE, fontSize: 62, bold: true, color: "FFFFFF",
    });
    s.addText("points de pourcentage", {
      x: 0.9, y: 3.35, w: 3.24, h: 0.32, align: "center", margin: 0,
      fontFace: POLICE, fontSize: 14, bold: true, color: C.orange,
    });
    s.addText(
      "d'écart de trajectoire défavorable aux enfants des ménages bénéficiaires, significatif au seuil de 5 %.",
      { x: 1.05, y: 3.85, w: 2.94, h: 1.0, align: "center", margin: 0, valign: "top",
        fontFace: POLICE, fontSize: 12.5, color: "D5DEEC", lineSpacing: 17 }
    );
    s.addText("H1 n'est pas validée", {
      x: 0.9, y: 5.5, w: 3.24, h: 0.4, align: "center", margin: 0, valign: "middle",
      fontFace: POLICE, fontSize: 15, bold: true, color: C.orange,
    });

    carte(p, s, 4.6, 1.42, 4.4, 4.95);
    s.addText("Recul de l'incidence entre 2018 et 2021", {
      x: 4.9, y: 1.68, w: 3.8, h: 0.34, margin: 0,
      fontFace: POLICE, fontSize: 13.5, bold: true, color: C.encre,
    });
    const BASE = 5.42, ECH = 0.29;
    [{ x: 5.35, v: 3.5, c: C.orange, t: "Bénéficiaires" },
     { x: 6.95, v: 9.9, c: C.bleu, t: "Témoins\nappariés" }].forEach((b) => {
      const h = b.v * ECH;
      s.addShape(p.ShapeType.roundRect, {
        x: b.x, y: BASE - h, w: 0.9, h, rectRadius: 0.04,
        fill: { color: b.c }, line: { type: "none" },
      });
      s.addText(vg(b.v) + " pts", {
        x: b.x - 0.3, y: BASE - h - 0.36, w: 1.5, h: 0.32, align: "center", margin: 0,
        fontFace: POLICE, fontSize: 15, bold: true, color: C.encre,
      });
      s.addText(b.t, {
        x: b.x - 0.35, y: BASE + 0.1, w: 1.6, h: 0.55, align: "center", margin: 0, valign: "top",
        fontFace: POLICE, fontSize: 11.5, bold: true, color: C.encre2, lineSpacing: 14,
      });
    });
    s.addShape(p.ShapeType.rect, {
      x: 5.05, y: BASE, w: 3.5, h: 0.02, fill: { color: "CFD4DD" }, line: { type: "none" },
    });
    s.addText("La pauvreté a reculé près de trois fois moins vite chez les bénéficiaires.", {
      x: 3.6, y: 6.05, w: 5.55, h: 0.34, align: "center", margin: 0,
      fontFace: POLICE, fontSize: 11, color: C.encre2,
    });

    carte(p, s, 9.28, 1.42, 3.35, 4.95);
    s.addText("Stable aux trois appariements", {
      x: 9.55, y: 1.68, w: 2.85, h: 0.34, margin: 0,
      fontFace: POLICE, fontSize: 13.5, bold: true, color: C.encre,
    });
    [["k plus proches voisins", "0,064", "**"], ["Noyau Epanechnikov", "0,061", "*"],
     ["Caliper", "0,050", "*"], ["Double différence brute", "0,035", ""]].forEach((r, i) => {
      const y = 2.2 + i * 0.72;
      s.addText(r[0], {
        x: 9.55, y, w: 1.95, h: 0.5, margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 11, color: C.encre2, lineSpacing: 14,
      });
      s.addText(r[1] + r[2], {
        x: 11.55, y, w: 0.85, h: 0.5, align: "right", margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 15, bold: true, color: r[2] ? C.bleufonce : C.muet,
      });
      s.addShape(p.ShapeType.rect, {
        x: 9.55, y: y + 0.56, w: 2.85, h: 0.012, fill: { color: C.grispale }, line: { type: "none" },
      });
    });
    s.addText("Le résultat ne tient pas au choix de l'algorithme. La double différence sans appariement, qui ne corrige pas l'avantage initial, donne le même signe atténué.", {
      x: 9.55, y: 5.2, w: 2.85, h: 1.05, margin: 0, valign: "top",
      fontFace: POLICE, fontSize: 10.5, color: C.encre2, lineSpacing: 14,
    });
    pied(s, "** significatif à 5 %, * à 10 %. " + SRC, ++n);
  }

  /* ============================================================
     17. Effets par dimension
     ============================================================ */
  {
    const s = slideContenu(p, "Où se concentre l'écart",
      "Sur les sept dimensions, une seule ressort : la nutrition, celle qui dépend le plus directement du budget courant du ménage.");

    carte(p, s, 0.72, 1.95, 7.2, 4.4);
    s.addText("Effet estimé par dimension, en points de pourcentage", {
      x: 1.05, y: 2.2, w: 6.6, h: 0.34, margin: 0,
      fontFace: POLICE, fontSize: 14, bold: true, color: C.encre,
    });
    const dims = [
      ["Nutrition", 6.8, true], ["Assainissement", 4.6, false], ["Eau", 2.4, false],
      ["Logement", 2.4, false], ["Protection", 1.1, false], ["Santé", 1.0, false],
      ["Éducation", 0.5, false],
    ];
    dims.forEach((d, i) => {
      const y = 2.72 + i * 0.5;
      s.addText(d[0], {
        x: 1.05, y, w: 1.6, h: 0.32, margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 11.5, bold: d[2], color: d[2] ? C.encre : C.encre2,
      });
      s.addShape(p.ShapeType.roundRect, {
        x: 2.75, y: y + 0.06, w: (d[1] / 6.8) * 3.75, h: 0.2, rectRadius: 0.025,
        fill: { color: d[2] ? C.orange : C.grispale }, line: { type: "none" },
      });
      s.addText("+" + vg(d[1]), {
        x: 6.65, y, w: 0.7, h: 0.32, align: "right", margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 12, bold: true, color: d[2] ? C.orange : C.encre2,
      });
      if (d[2]) {
        s.addText("*", {
          x: 7.35, y, w: 0.3, h: 0.32, margin: 0, valign: "middle",
          fontFace: POLICE, fontSize: 14, bold: true, color: C.orange,
        });
      }
    });

    carte(p, s, 8.2, 1.95, 4.43, 2.05, C.rose);
    await pastille(s, 8.5, 2.25, 0.85, C.orange, I.FaBaby);
    s.addText("+9,1 points chez les 0 à 4 ans", {
      x: 9.5, y: 2.28, w: 2.85, h: 0.5, margin: 0, valign: "middle",
      fontFace: POLICE, fontSize: 14, bold: true, color: C.encre, lineSpacing: 17,
    });
    s.addText("Significatif à 5 %. Effet par âge et effet par dimension se répondent : les besoins des plus jeunes passent d'abord par l'alimentation.", {
      x: 8.5, y: 3.2, w: 3.85, h: 0.7, margin: 0, valign: "top",
      fontFace: POLICE, fontSize: 11, color: C.encre2, lineSpacing: 14.5,
    });

    carte(p, s, 8.2, 4.3, 4.43, 2.05);
    s.addText("Aucun test d'égalité ne conclut", {
      x: 8.5, y: 4.55, w: 3.85, h: 0.34, margin: 0,
      fontFace: POLICE, fontSize: 14, bold: true, color: C.encre,
    });
    [["Milieu de résidence", "p = 0,863"], ["Genre du chef de ménage", "p = 0,879"], ["Groupe d'âge", "p = 0,252"]]
      .forEach((t, i) => {
        const y = 5.0 + i * 0.42;
        s.addText(t[0], {
          x: 8.5, y, w: 2.6, h: 0.3, margin: 0,
          fontFace: POLICE, fontSize: 11.5, color: C.encre2,
        });
        s.addText(t[1], {
          x: 11.2, y, w: 1.15, h: 0.3, align: "right", margin: 0,
          fontFace: POLICE, fontSize: 11.5, bold: true, color: C.encre,
        });
      });
    s.addText("Les sous-groupes se distinguent par la significativité de leur effet, non par une ampleur supérieure.", {
      x: 8.5, y: 6.28, w: 3.85, h: 0.04, margin: 0, fontFace: POLICE, fontSize: 1, color: C.surface,
    });
    pied(s, "* significatif à 10 %. Appariement au plus proche voisin. " + SRC, ++n);
  }

  /* ============================================================
     18. Effet selon le montant
     ============================================================ */
  {
    const s = slideContenu(p, "Un gradient selon le montant reçu",
      "L'écart défavorable se concentre sur les plus faibles montants et ne se retrouve pas pour les transferts les plus élevés.");

    carte(p, s, 0.72, 1.95, 7.6, 4.4);
    const q = [
      ["Q1", "jusqu'à 100 000 FCFA", 12.9, true],
      ["Q2", "110 000 à 360 000", 9.9, true],
      ["Q3", "380 000 à 900 000", 2.0, false],
      ["Q4", "920 000 à 1 800 000", 8.4, false],
      ["Q5", "au-delà de 1 824 000", -0.8, false],
    ];
    s.addText("Effet estimé par quintile de montant annuel, en points", {
      x: 1.05, y: 2.2, w: 7.0, h: 0.34, margin: 0,
      fontFace: POLICE, fontSize: 14, bold: true, color: C.encre,
    });
    const ZERO = 3.3;
    q.forEach((r, i) => {
      const y = 2.78 + i * 0.66;
      s.addText(r[0], {
        x: 1.05, y, w: 0.42, h: 0.42, margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 13, bold: true, color: r[3] ? C.orange : C.encre2,
      });
      s.addText(r[1], {
        x: 1.5, y, w: 1.62, h: 0.42, margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 10.5, color: C.muet,
      });
      const w = Math.abs(r[2]) / 12.9 * 3.9;
      s.addShape(p.ShapeType.roundRect, {
        x: r[2] >= 0 ? ZERO : ZERO - w, y: y + 0.09, w: Math.max(w, 0.05), h: 0.24, rectRadius: 0.03,
        fill: { color: r[3] ? C.orange : C.grispale }, line: { type: "none" },
      });
      s.addText((r[2] >= 0 ? "+" : "−") + vg(Math.abs(r[2])), {
        x: ZERO + (r[2] >= 0 ? w + 0.08 : 0.12), y, w: 0.7, h: 0.42,
        align: "left", margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 12, bold: true, color: r[3] ? C.orange : C.encre2,
      });
      if (r[3]) {
        s.addText("**", {
          x: (ZERO + w + 0.80), y, w: 0.3, h: 0.42, margin: 0, valign: "middle",
          fontFace: POLICE, fontSize: 13, bold: true, color: C.orange,
        });
      }
    });
    s.addShape(p.ShapeType.rect, {
      x: ZERO, y: 2.72, w: 0.015, h: 3.35, fill: { color: "B9C0CC" }, line: { type: "none" },
    });

    carte(p, s, 8.6, 1.95, 4.03, 2.05, C.bleufonce);
    s.addText("−0,025", {
      x: 8.85, y: 2.2, w: 3.55, h: 0.6, align: "center", margin: 0, valign: "middle",
      fontFace: POLICE, fontSize: 34, bold: true, color: "FFFFFF",
    });
    s.addText("pente dose-réponse, significative à 10 %", {
      x: 8.85, y: 2.82, w: 3.55, h: 0.3, align: "center", margin: 0,
      fontFace: POLICE, fontSize: 11.5, bold: true, color: C.orange,
    });
    s.addText("Plus le montant reçu est élevé, plus l'écart de trajectoire tend à se réduire.", {
      x: 8.85, y: 3.2, w: 3.55, h: 0.62, align: "center", margin: 0, valign: "top",
      fontFace: POLICE, fontSize: 11, color: "D5DEEC", lineSpacing: 14.5,
    });

    carte(p, s, 8.6, 4.3, 4.03, 2.05);
    s.addText("Comment le lire", {
      x: 8.9, y: 4.55, w: 3.45, h: 0.34, margin: 0,
      fontFace: POLICE, fontSize: 14, bold: true, color: C.encre,
    });
    s.addText(
      "Le profil n'est pas strictement monotone, le quatrième quintile remontant sans être significatif. " +
      "Le montant relevant du choix du migrant, le gradient se lit comme une association conditionnelle.",
      { x: 8.9, y: 4.95, w: 3.45, h: 1.3, margin: 0, valign: "top",
        fontFace: POLICE, fontSize: 11, color: C.encre2, lineSpacing: 14.5 }
    );
    pied(s, "** significatif à 5 %. " + SRC, ++n);
  }

  /* ============================================================
     19. Section 5 : robustesse
     ============================================================ */
  { slideSection(p, "05", "Robustesse et discussion", "Ce que le résultat supporte, et ce qu'il ne prouve pas."); n++; }

  /* ============================================================
     20. Robustesse
     ============================================================ */
  {
    const s = slideContenu(p, "Tests de robustesse");
    const tests = [
      { ic: I.FaUsers, c: C.bleu, t: "Méthode d'appariement",
        d: "Trois algorithmes, effet de 0,050 à 0,064, tous significatifs au moins à 10 %.", ok: "Le résultat tient" },
      { ic: I.FaChartLine, c: C.teal, t: "Seuil de privation",
        d: "Testé de 1 à 7 dimensions, l'ampleur suit une courbe en cloche, maximale au seuil retenu.", ok: "Le signe tient" },
      { ic: I.FaMagnifyingGlass, c: C.or, t: "Validation croisée",
        d: "Une implémentation indépendante du même estimateur retrouve le résultat.", ok: "Le résultat tient" },
      { ic: I.FaTriangleExclamation, c: C.orange, t: "Définition alternative",
        d: "Chez les bénéficiaires de longue date, l'écart ne se retrouve pas (0,022 et −0,008, non significatifs).", ok: "À nuancer" },
    ];
    for (let i = 0; i < tests.length; i++) {
      const t = tests[i];
      const x = 0.72 + (i % 2) * 6.13;
      const y = 1.62 + Math.floor(i / 2) * 2.45;
      carte(p, s, x, y, 5.78, 2.15);
      await pastille(s, x + 0.3, y + 0.32, 0.85, t.c, t.ic);
      s.addText(t.t, {
        x: x + 1.32, y: y + 0.3, w: 2.98, h: 0.42, margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 15, bold: true, color: C.encre,
      });
      s.addText(t.ok, {
        x: x + 4.4, y: y + 0.32, w: 1.15, h: 0.36, align: "right", margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 11, bold: true, color: t.c,
      });
      s.addText(t.d, {
        x: x + 0.3, y: y + 1.3, w: 5.2, h: 0.7, margin: 0, valign: "top",
        fontFace: POLICE, fontSize: 12, color: C.encre2, lineSpacing: 16.5,
      });
    }
    carte(p, s, 0.72, 6.52, 11.91, 0.0001, C.surface);
    pied(s, SRC, ++n);
  }

  /* ============================================================
     21. Validation des hypothèses
     ============================================================ */
  {
    const s = slideContenu(p, "Validation des hypothèses");
    [
      { h: "H1", e: "Les transferts réduisent significativement la pauvreté multidimensionnelle des enfants.",
        r: "L'effet estimé vaut +0,064, significatif à 5 %, et de signe défavorable : aucune réduction n'est observée sur l'horizon.",
        d: "Non validée", c: C.orange, ic: I.FaXmark },
      { h: "H2", e: "L'impact est hétérogène selon les dimensions, le milieu, le genre du chef, l'âge et le montant.",
        r: "L'effet n'est établi que sur la nutrition et chez les 0 à 4 ans, avec un gradient net selon le montant. Aucun test d'égalité ne conclut par milieu, genre du chef ou âge.",
        d: "Partiellement validée", c: C.teal, ic: I.FaCheck },
    ].forEach(async (b, i) => {
      const y = 1.62 + i * 2.55;
      carte(p, s, 0.72, y, 11.91, 2.25);
      s.addText(b.h, {
        x: 1.75, y: y + 0.35, w: 0.9, h: 0.5, margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 26, bold: true, color: b.c,
      });
      s.addText(b.e, {
        x: 1.75, y: y + 0.95, w: 3.4, h: 0.95, margin: 0, valign: "top",
        fontFace: POLICE, fontSize: 12, italic: true, color: C.encre2, lineSpacing: 16,
      });
      s.addText(b.r, {
        x: 5.5, y: y + 0.42, w: 5.05, h: 1.45, margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 12.5, color: C.encre, lineSpacing: 17,
      });
      s.addText(b.d, {
        x: 10.75, y: y + 0.85, w: 1.65, h: 0.55, align: "center", margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 13.5, bold: true, color: b.c,
      });
    });
    for (let i = 0; i < 2; i++) {
      const cs = [C.orange, C.teal], ics = [I.FaXmark, I.FaCheck];
      await pastille(s, 1.02, 1.62 + i * 2.55 + 0.68, 0.62, cs[i], ics[i]);
    }
    pied(s, null, ++n);
  }

  /* ============================================================
     22. Interprétation
     ============================================================ */
  {
    const s = slideContenu(p, "Comment comprendre ce résultat",
      "Le résultat ne dit pas que les transferts appauvrissent les enfants : il dit que les conditions de vie s'améliorent plus lentement chez les bénéficiaires.");
    const mec = [
      { ic: I.FaMoneyBillTransfer, c: C.or, t: "L'usage des fonds",
        d: "68,5 % des transferts relèvent du soutien courant, moins d'un dixième va explicitement à la santé ou à la scolarité. Un flux qui finance l'ordinaire déplace peu les seuils de privation." },
      { ic: I.FaFaucet, c: C.bleu, t: "La contrainte d'offre",
        d: "L'eau, l'assainissement et l'accès aux soins supposent des investissements collectifs. Le pouvoir d'achat supplémentaire ne les crée pas : la privation en santé touche 97 % des enfants aux deux vagues." },
      { ic: I.FaChartLine, c: C.teal, t: "La marge sur laquelle l'effet opère",
        d: "La sensibilité au seuil montre que l'écart se joue au milieu de la distribution des privations. Le noyau des enfants les plus démunis relève de déficits qu'aucun flux privé ne déplace en trois ans." },
    ];
    for (let i = 0; i < mec.length; i++) {
      const m = mec[i];
      const x = 0.72 + i * 4.15;
      carte(p, s, x, 1.85, 3.78, 4.5);
      await pastille(s, x + 1.45, 2.15, 0.9, m.c, m.ic);
      s.addText(m.t, {
        x: x + 0.3, y: 3.2, w: 3.2, h: 0.65, align: "center", margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 14.5, bold: true, color: C.encre, lineSpacing: 18,
      });
      s.addText(m.d, {
        x: x + 0.3, y: 3.95, w: 3.2, h: 2.2, margin: 0, valign: "top",
        fontFace: POLICE, fontSize: 11.5, color: C.encre2, lineSpacing: 16,
      });
    }
    pied(s, null, ++n);
  }

  /* ============================================================
     23. Limites
     ============================================================ */
  {
    const s = slideContenu(p, "Limites et perspectives");
    carte(p, s, 0.72, 1.55, 5.9, 4.8);
    await pastille(s, 1.05, 1.85, 0.85, C.orange, I.FaTriangleExclamation);
    s.addText("Limites de l'étude", {
      x: 2.1, y: 1.9, w: 4.3, h: 0.4, margin: 0, valign: "middle",
      fontFace: POLICE, fontSize: 17, bold: true, color: C.encre,
    });
    [
      { t: "Tendances parallèles", d: "L'hypothèse n'est pas testable directement, deux vagues seulement étant disponibles. L'appariement sur les niveaux initiaux la rend plus crédible." },
      { t: "Vieillissement des enfants", d: "Chaque enfant est évalué sur la grille de son âge courant à chaque vague. Les groupes d'âge figés à la période de base neutralisent l'essentiel de cet effet." },
    ].forEach((l, i) => {
      const y = 3.0 + i * 1.72;
      s.addText(l.t, {
        x: 1.05, y, w: 5.25, h: 0.32, margin: 0,
        fontFace: POLICE, fontSize: 13.5, bold: true, color: C.orange,
      });
      s.addText(l.d, {
        x: 1.05, y: y + 0.36, w: 5.25, h: 1.2, margin: 0, valign: "top",
        fontFace: POLICE, fontSize: 12, color: C.encre2, lineSpacing: 16.5,
      });
    });

    carte(p, s, 6.85, 1.55, 5.78, 4.8);
    await pastille(s, 7.18, 1.85, 0.85, C.teal, I.FaLightbulb);
    s.addText("Perspectives", {
      x: 8.23, y: 1.9, w: 4.15, h: 0.4, margin: 0, valign: "middle",
      fontFace: POLICE, fontSize: 17, bold: true, color: C.encre,
    });
    [
      "Analyser les mécanismes de transmission, dépenses en éducation, en santé et en logement.",
      "Intégrer la durée d'exposition aux transferts et leurs usages effectifs.",
      "Étendre l'analyse aux autres pays de l'UEMOA couverts par l'EHCVM.",
    ].forEach((t, i) => {
      const y = 3.0 + i * 1.12;
      s.addShape(p.ShapeType.ellipse, {
        x: 7.18, y: y + 0.06, w: 0.32, h: 0.32, fill: { color: C.teal }, line: { type: "none" },
      });
      s.addText(String(i + 1), {
        x: 7.18, y: y + 0.07, w: 0.32, h: 0.3, align: "center", margin: 0,
        fontFace: POLICE, fontSize: 12, bold: true, color: "FFFFFF",
      });
      s.addText(t, {
        x: 7.68, y, w: 4.6, h: 0.9, margin: 0, valign: "top",
        fontFace: POLICE, fontSize: 12, color: C.encre2, lineSpacing: 16.5,
      });
    });
    pied(s, null, ++n);
  }

  /* ============================================================
     24. Section 6 : conclusion
     ============================================================ */
  { slideSection(p, "06", "Conclusion et recommandations", "Ce que l'étude établit, et ce qu'il faut en faire."); n++; }

  /* ============================================================
     25. Conclusion
     ============================================================ */
  {
    const s = slideContenu(p, "Ce que l'étude établit");
    carte(p, s, 0.72, 1.55, 11.91, 1.55, C.bleufonce);
    s.addText(
      "Sur l'horizon 2018-2021, les transferts de migrants n'ont pas réduit la pauvreté multidimensionnelle des enfants au Sénégal.",
      { x: 1.2, y: 1.72, w: 10.95, h: 1.2, align: "center", margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 19, bold: true, color: "FFFFFF", lineSpacing: 27 }
    );
    const pts = [
      { v: "+6,4", u: "points", t: "d'écart de trajectoire, significatif à 5 % et stable aux trois appariements.", c: C.orange },
      { v: "1", u: "dimension", t: "sur sept ressort, la nutrition, et un seul groupe d'âge, les 0 à 4 ans.", c: C.bleu },
      { v: "Q1-Q2", u: "seulement", t: "les deux premiers quintiles de montant portent l'écart observé.", c: C.teal },
      { v: "0", u: "test concluant", t: "par milieu, genre du chef de ménage ou tranche d'âge.", c: C.or },
    ];
    pts.forEach((b, i) => {
      const x = 0.72 + i * 3.05;
      carte(p, s, x, 3.35, 2.75, 3.0);
      s.addText(b.v, {
        x: x + 0.15, y: 3.62, w: 2.45, h: 0.75, align: "center", margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 36, bold: true, color: b.c,
      });
      s.addText(b.u, {
        x: x + 0.15, y: 4.38, w: 2.45, h: 0.3, align: "center", margin: 0,
        fontFace: POLICE, fontSize: 12, bold: true, color: C.encre,
      });
      s.addText(b.t, {
        x: x + 0.22, y: 4.8, w: 2.32, h: 1.35, align: "center", margin: 0, valign: "top",
        fontFace: POLICE, fontSize: 11.5, color: C.encre2, lineSpacing: 16,
      });
    });
    pied(s, null, ++n);
  }

  /* ============================================================
     26. Recommandations
     ============================================================ */
  {
    const s = slideContenu(p, "Recommandations de politique économique",
      "Elles suivent l'ordre des faits établis, de la dimension et du groupe d'âge sur lesquels l'écart se concentre jusqu'aux conditions de conversion des transferts.");
    const recos = [
      { ic: I.FaBasketShopping, c: C.or, t: "Sécurité alimentaire et enfants de 0 à 4 ans",
        d: "Filets sociaux, cantines scolaires et suivi nutritionnel en priorité dans les communes d'émigration, sans écarter les ménages bénéficiaires au motif qu'ils reçoivent une ressource extérieure." },
      { ic: I.FaFaucet, c: C.bleu, t: "Compléter par l'offre publique de services",
        d: "L'eau, l'assainissement et la santé relèvent d'investissements collectifs que le pouvoir d'achat privé ne remplace pas. Cibler prioritairement les communes rurales d'émigration." },
      { ic: I.FaHandHoldingDollar, c: C.teal, t: "Cibler les petits montants, réduire les coûts",
        d: "Accompagner les ménages qui reçoivent le moins, et réduire les coûts de transaction des envois formels pour accroître les fonds réellement disponibles." },
    ];
    for (let i = 0; i < recos.length; i++) {
      const r = recos[i];
      const y = 1.95 + i * 1.55;
      carte(p, s, 0.72, y, 11.91, 1.35);
      await pastille(s, 1.05, y + 0.24, 0.88, r.c, r.ic);
      s.addText(r.t, {
        x: 2.15, y: y + 0.2, w: 3.5, h: 0.95, margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 14.5, bold: true, color: C.encre, lineSpacing: 18,
      });
      s.addText(r.d, {
        x: 5.9, y: y + 0.2, w: 6.4, h: 0.95, margin: 0, valign: "middle",
        fontFace: POLICE, fontSize: 12, color: C.encre2, lineSpacing: 16.5,
      });
    }
    pied(s, null, ++n);
  }

  /* ============================================================
     27. Remerciements
     ============================================================ */
  {
    const s = p.addSlide();
    s.background = { color: C.bleunuit };
    s.addShape(p.ShapeType.ellipse, { x: 9.8, y: -2.0, w: 6.0, h: 6.0, fill: { color: "23236B" }, line: { type: "none" } });
    s.addShape(p.ShapeType.ellipse, { x: -2.2, y: 4.4, w: 5.2, h: 5.2, fill: { color: "23236B" }, line: { type: "none" } });
    s.addText("Merci de votre attention", {
      x: 1.0, y: 2.75, w: 11.33, h: 1.0, align: "center", margin: 0, valign: "middle",
      fontFace: POLICE, fontSize: 42, bold: true, color: "FFFFFF",
    });
    s.addText("Sié Rachid TRAORÉ   ·   sous la direction de Mamadou Abdoulaye DIALLO", {
      x: 1.0, y: 3.95, w: 11.33, h: 0.34, align: "center", margin: 0,
      fontFace: POLICE, fontSize: 14, color: C.orange,
    });
    s.addText("ENSAE Pierre Ndiaye   ·   Août 2026", {
      x: 1.0, y: 4.35, w: 11.33, h: 0.32, align: "center", margin: 0,
      fontFace: POLICE, fontSize: 12.5, color: "8FA6CC",
    });
    n++;
  }

  await p.writeFile({ fileName: "presentation_infographique.pptx" });
  console.log(">>> presentation_infographique.pptx genere, " + n + " diapositives");
}

main().catch((e) => { console.error(e); process.exit(1); });
