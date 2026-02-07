const content = {
  name: "Victor",
  surname: "Patrin",
  tagline: "senior devops & software engineer, montreal",

  links: [
    { label: "github", url: "https://github.com/vpatrin" },
    { label: "linkedin", url: "https://www.linkedin.com/in/victorpatrin/" },
    { label: "email", url: "mailto:victor.patrin@protonmail.com" },
  ],

  available: {
    title: "Available for freelance",
    description:
      "6+ years building backend systems, cloud infrastructure, and data pipelines. Currently taking on freelance projects and fractional DevOps consulting.",
    services:
      "Cloud migration / Kubernetes & GKE ops / CI-CD pipelines / Python backend dev / Security & compliance",
  },

  about: [
    'Senior Software Engineer with a dual Master\'s from <span class="highlight">Mines de Nancy</span> and a specialization in <span class="highlight">Information & Systems Security</span>. Spent 6 years at a Montreal AI startup — started as an intern, left as Senior Engineer and de facto technical lead after our CTO departed.',
    "Built search engines from scratch, migrated monoliths to microservices, managed production Kubernetes clusters on GCP, and designed deployment systems that replaced expensive third-party tools.",
  ],

  stack: [
    { label: "languages", value: "Python, Node.js, Bash" },
    { label: "cloud", value: "GCP, GKE, Pub/Sub, Cloud Storage" },
    { label: "devops", value: "Docker, Kubernetes, Helm, CI/CD" },
    { label: "data", value: "PostgreSQL, ETL pipelines, microservices" },
    { label: "security", value: "InfoSec, access control, web app security" },
  ],

  projects: [
    {
      name: "url-shortener",
      url: "https://s.victorpatrin.dev",
      status: "soon",
      desc: "High-performance link shortener with click analytics",
      stack: "FastAPI / PostgreSQL / Redis / Docker",
    },
    {
      name: "saq-watcher",
      url: "#",
      status: "planned",
      desc: "Automated scraper for SAQ new arrivals with notifications",
      stack: "Python / BeautifulSoup / Cron / Telegram",
    },
    {
      name: "wine-cellar-api",
      url: "#",
      status: "planned",
      desc: "REST API for wine collection management with JWT auth",
      stack: "FastAPI / PostgreSQL / JWT",
    },
    {
      name: "ask-my-docs",
      url: "#",
      status: "planned",
      desc: "Upload PDFs, ask questions — reusable RAG template for clients",
      stack: "LangChain / ChromaDB / FastAPI / React",
    },
  ],

  experience: [
    {
      role: "Senior Software Engineer",
      date: "2022 — 2025",
      company: "GENAIZ, Montreal",
      desc: "DevOps lead. Managed GKE clusters, built CI/CD from scratch, deployed client solutions, mentored junior devs. Became primary technical contact after CTO departure.",
    },
    {
      role: "Software Engineer",
      date: "2019 — 2022",
      company: "GENAIZ, Montreal",
      desc: "Built an in-house search engine with dockerized Python microservices. Migrated Node.js monolith to microservices architecture. Maintained production data pipelines on GCP.",
    },
    {
      role: "Junior Developer",
      date: "2018 — 2019",
      company: "ubirch GmbH, Berlin",
      desc: "Developed mobile app for cryptographic identity verification using Bluetooth BLE. Built data anchoring services on IOTA, Ethereum, and MultiChain.",
    },
  ],

  education: [
    {
      role: "MSc Information & Systems Security",
      date: "2018 — 2019",
      company: "Faculty of Sciences, Nancy",
    },
    {
      role: "MSc Cross Sector Engineering — CS & IT",
      date: "2016 — 2019",
      company: "Mines de Nancy",
    },
    {
      role: "Classe Préparatoire (Math, CS, Physics)",
      date: "2013 — 2016",
      company: "Lycée Gay-Lussac, Limoges",
    },
  ],

  footer: {
    left: "Built with raw HTML, served by Caddy on Debian 13",
    email: "victor.patrin@protonmail.com",
    location: "Montreal, QC",
  },
};
