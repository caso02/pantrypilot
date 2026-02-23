import { getPrisma } from "../db/client.js";
import { upsertProductsFromSearch } from "../services/product-service.js";

const QUERIES = [
  // Milchprodukte
  "Milch", "Joghurt", "Käse", "Butter", "Rahm", "Quark", "Mozzarella",
  "Emmentaler", "Gruyère", "Mascarpone", "Crème fraîche", "Cottage Cheese",
  "Ricotta", "Hüttenkäse", "Raclette", "Fondue", "Sbrinz", "Tilsiter",
  "Appenzeller", "Parmesan", "Feta", "Halloumi", "Ziger", "Frischkäse",
  "Skyr", "Kefir", "Buttermilch", "Schlagrahm", "Halbrahm", "Sauermilch",
  "Schmand", "Sauerrahm", "Acidoplus",
  // Eier
  "Eier", "Freilandeier", "Bio Eier",
  // Brot & Backwaren
  "Brot", "Zopf", "Gipfeli", "Brötchen", "Toast", "Knäckebrot", "Ruchbrot",
  "Vollkornbrot", "Weggli", "Laugenbrötchen", "Baguette", "Ciabatta",
  "Pumpernickel", "Dinkelbrot", "Tessiner Brot", "Butterzopf", "Nussgipfel",
  "Croissant", "Pain au chocolat", "Berliner", "Hefezopf",
  // Fleisch
  "Poulet", "Rindfleisch", "Schweinefleisch", "Hackfleisch", "Kalbfleisch",
  "Pouletbrust", "Cervelat", "Schinken", "Salami", "Wienerli", "Bratwurst",
  "Trockenfleisch", "Plätzli", "Entrecôte", "Geschnetzeltes", "Filet",
  "Lammfleisch", "Braten", "Cordon bleu", "Schnitzel", "Pouletschenkel",
  "Hamburger", "Fleischkäse", "Aufschnitt", "Landjäger", "Bündnerfleisch",
  "Salsiz", "Speck", "Pancetta", "Poulet Nuggets", "Siedfleisch",
  "Kotelett", "Rippli", "Gnagi", "Lyoner", "Mortadella",
  // Fisch & Meeresfrüchte
  "Lachs", "Crevetten", "Thunfisch", "Forelle", "Pangasius",
  "Räucherlachs", "Fischstäbchen", "Garnelen", "Kabeljau", "Dorsch",
  "Sardinen", "Calamari", "Muscheln", "Seelachs", "Sushi",
  // Früchte
  "Äpfel", "Bananen", "Erdbeeren", "Trauben", "Orangen", "Birnen",
  "Zitronen", "Limetten", "Mandarinen", "Clementinen", "Kiwi",
  "Mango", "Ananas", "Wassermelone", "Honigmelone", "Pfirsich",
  "Nektarinen", "Aprikosen", "Kirschen", "Zwetschgen", "Himbeeren",
  "Blaubeeren", "Heidelbeeren", "Brombeeren", "Johannisbeeren", "Feigen",
  "Granatapfel", "Passionsfrucht", "Litschi", "Papaya", "Grapefruit",
  "Pomelo", "Datteln", "Pflaumen", "Mirabellen",
  // Gemüse
  "Tomaten", "Gurke", "Karotten", "Salat", "Paprika", "Zwiebeln",
  "Kartoffeln", "Broccoli", "Zucchetti", "Champignons", "Avocado",
  "Spinat", "Aubergine", "Blumenkohl", "Peperoni", "Lauch",
  "Knoblauch", "Ingwer", "Sellerie", "Fenchel", "Randen",
  "Kürbis", "Süsskartoffeln", "Spargel", "Erbsen", "Mais",
  "Rüebli", "Kabis", "Rosenkohl", "Kohlrabi", "Chinakohl",
  "Nüsslisalat", "Rucola", "Eisbergsalat", "Kopfsalat", "Endivie",
  "Chicorée", "Mangold", "Pak Choi", "Radieschen", "Rettich",
  "Chili", "Jalapeño", "Frühlingszwiebeln", "Schalotten",
  "Artischocken", "Bohnen grün", "Edamame", "Kefen",
  "Petersilie", "Basilikum", "Schnittlauch", "Rosmarin", "Thymian",
  "Dill", "Koriander", "Minze", "Salbei",
  // Teigwaren, Reis & Getreide
  "Pasta", "Spaghetti", "Penne", "Reis", "Risotto", "Couscous",
  "Nudeln", "Tortellini", "Gnocchi", "Fusilli", "Farfalle",
  "Tagliatelle", "Lasagne", "Cannelloni", "Spätzle", "Hörnli",
  "Spiralen", "Basmatireis", "Jasminreis", "Wildreis", "Quinoa",
  "Bulgur", "Polenta", "Ebly", "Buchweizen", "Hirse",
  // Getränke
  "Orangensaft", "Mineralwasser", "Apfelsaft", "Eistee", "Cola",
  "Rivella", "Bier", "Wein", "Kaffee", "Tee", "Kakao", "Ovomaltine",
  "Sirup", "Energy Drink", "Smoothie", "Gazosa", "Tonic Water",
  "Prosecco", "Sekt", "Multivitaminsaft", "Traubensaft", "Cranberrysaft",
  "Espresso", "Lungo", "Nespresso", "Kaffeekapseln", "Filterkaffee",
  "Grüntee", "Pfefferminztee", "Kamillentee", "Früchtetee",
  // Frühstück & Müesli
  "Müesli", "Cornflakes", "Birchermüesli", "Haferflocken", "Granola",
  "Nutella", "Konfitüre", "Honig", "Ahornsirup", "Erdnussbutter",
  "Crunchy", "Porridge",
  // Süsses & Snacks
  "Schokolade", "Chips", "Guetzli", "Glacé", "Gummibärchen",
  "Nüsse", "Studentenfutter", "Kekse", "Mailänderli",
  "Cailler", "Toblerone", "Lindor", "Ragusa", "Zweifel",
  "Popcorn", "Salzstangen", "Reiswaffeln", "Trockenfrüchte",
  "Mandeln", "Cashewnüsse", "Pistazien", "Baumnüsse",
  "Erdnüsse", "Haselnüsse", "Macadamia",
  "Muffin", "Cake", "Torte", "Kuchen", "Brownies",
  // Basics & Gewürze
  "Mehl", "Zucker", "Salz", "Pfeffer", "Olivenöl", "Sonnenblumenöl",
  "Essig", "Senf", "Ketchup", "Mayonnaise", "Sojasauce",
  "Rapsöl", "Kokosöl", "Sesamöl", "Balsamico", "Weinessig",
  "Backpulver", "Hefe", "Vanillezucker", "Puderzucker", "Rohrzucker",
  "Zimt", "Paprikapulver", "Currypulver", "Kurkuma", "Oregano",
  "Muskatnuss", "Lorbeerblätter", "Chilipulver", "Kreuzkümmel",
  "Bratbutter", "Bratcrème", "Stärkemehl", "Maizena",
  // Saucen & Würze
  "Tabasco", "Sriracha", "Barbecuesauce", "Cocktailsauce",
  "Tartarsauce", "Pesto", "Tomatenpüree", "Harissa",
  "Sambal Oelek", "Worcestersauce", "Hoisin", "Teriyaki",
  // Konserven & Fertig
  "Tomatensugo", "Kokosmilch", "Bouillon", "Ravioli", "Pizza",
  "Dosentomaten", "Maiskörner", "Kichererbsen", "Linsen", "Bohnen",
  "Sauerkraut", "Gewürzgurken", "Oliven", "Kapern", "Sardellen",
  "Rösti", "Stocki", "Suppe", "Brühe", "Fond",
  // Tiefkühl
  "Tiefkühlpizza", "Pommes Frites", "Tiefkühlgemüse", "Fischstäbchen",
  "Tiefkühlbeeren", "Rahmspinat", "Blätterteig", "Kuchenteig",
  "Glacé Cornet", "Glace Stengel", "Sorbet",
  // Tofu & Vegan
  "Tofu", "Tempeh", "Seitan", "Sojamilch", "Hafermilch", "Mandelmilch",
  "Kokosmilch", "Reismilch", "Veganer Käse", "Planted", "Quorn",
  "Vegan Joghurt", "V-Love",
  // Hygiene & Haushalt
  "Waschmittel", "Spülmittel", "Toilettenpapier", "Zahnpasta",
  "Shampoo", "Seife", "Deo", "Rasierer", "Duschgel",
  "Handseife", "Desinfektionsmittel", "Taschentücher",
  "Küchenrolle", "Müllbeutel", "Alufolie", "Backpapier",
  "Frischhaltefolie", "Schwamm", "Putzmittel", "Weichspüler",
  // Baby & Spezial
  "Babynahrung", "Windeln",
  // M-Budget / M-Classic / Alnatura / Bio
  "M-Budget", "M-Classic", "Bio Migros", "Alnatura", "Demeter",
  "Anna's Best", "Sélection",
];

async function bulkImport() {
  const prisma = getPrisma();

  const startCount = await prisma.product.count();
  console.log(`[bulk] Start: ${startCount} Produkte in DB`);
  console.log(`[bulk] ${QUERIES.length} Suchbegriffe werden abgearbeitet...\n`);

  let totalNew = 0;

  for (let i = 0; i < QUERIES.length; i++) {
    const query = QUERIES[i];
    const before = await prisma.product.count();

    try {
      const count = await upsertProductsFromSearch(query);
      const after = await prisma.product.count();
      const newOnes = after - before;
      totalNew += newOnes;
      console.log(
        `[${String(i + 1).padStart(3)}/${QUERIES.length}] "${query}" → ${count} geholt, ${newOnes} neu (Total: ${after})`
      );
    } catch (err: any) {
      console.error(
        `[${String(i + 1).padStart(3)}/${QUERIES.length}] "${query}" → FEHLER: ${err.message}`
      );
    }

    // Rate limiting: 1.5s zwischen Requests
    await new Promise((r) => setTimeout(r, 1500));
  }

  const finalCount = await prisma.product.count();
  console.log(`\n[bulk] Fertig! ${finalCount} Produkte in DB (+${totalNew} neu)`);

  await prisma.$disconnect();
  process.exit(0);
}

bulkImport().catch((err) => {
  console.error("[bulk] Fatal:", err);
  process.exit(1);
});
