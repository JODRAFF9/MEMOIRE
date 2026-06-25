pays <- c("Benin","Burkina Faso","Cote d'Ivoire","Guinee-Bissau",
          "Mali","Niger","Senegal","Togo")

annees <- 2000:2025

base <- expand.grid(pays = pays, annee = annees)

entry_year <- c(2008,2008,2013,2012,2009,2007,2013,2010)

base$ITIE <- as.numeric(base$annee >= entry_year[match(base$pays, pays)])