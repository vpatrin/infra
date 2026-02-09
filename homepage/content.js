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
    title: "Available for freelance — remote worldwide",
    description:
      "6+ years shipping backend systems, cloud infrastructure, and data pipelines at a Montreal AI startup. From intern to Senior Engineer, including a stint as interim tech lead. Currently taking on freelance projects and fractional DevOps consulting.",
    services:
      "Cloud migration / Kubernetes & GKE ops / CI-CD pipelines / Python backend dev / Data pipelines & ETL / Security & compliance",
  },

  about: [
    'French engineer based in Montreal since 2019. Dual Master\'s from <span class="highlight">Mines de Nancy</span> (engineering) and <span class="highlight">Université de Lorraine</span> (Information & Systems Security), with a foundation in advanced mathematics from classe préparatoire MPSI/MP.',
    'Spent 6+ years at <span class="highlight">GENAIZ</span>, an AI startup — joined as a blockchain intern, left as Senior Engineer running DevOps and cloud ops. Built search engines from scratch, migrated a Node.js monolith to dockerized Python microservices, managed production GKE clusters, and designed a CI/CD system that replaced a costly third-party service. Served as interim tech lead during a period without CTO.',
    "Previous experience in Berlin at a blockchain-for-IoT startup, implementing data anchoring on Ethereum, IOTA, and MultiChain.",
  ],

  stack: [
    { label: "languages", value: "Python, Node.js" },
    { label: "cloud", value: "GCP, GKE, Pub/Sub, Cloud Storage" },
    { label: "devops", value: "Docker, Kubernetes, Helm, CI/CD" },
    { label: "data", value: "PostgreSQL, MongoDB, ETL pipelines" },
    { label: "security", value: "InfoSec, access control, web app security" },
    { label: "infra", value: "Terraform, haproxy, Caddy, Let's Encrypt & cert-manager" },
    { label: "other", value: "Blockchain, distributed systems, cryptography" },
  ],

  projects: [
    {
      name: "url-shortener",
      url: "https://s.victorpatrin.dev",
      status: "live",
      desc: "High-performance link shortener with click analytics",
      stack: "FastAPI / PostgreSQL / Redis / Docker",
    },
    {
      name: "saq-watcher",
      url: "#",
      status: "soon",
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
      desc: "Self-hosted NotebookLM-style app — upload PDFs, ask questions",
      stack: "LangChain / ChromaDB / FastAPI / React",
    },
  ],

  experience: [
    {
      role: "Senior Software Engineer",
      date: "2022 — 2025",
      company: "GENAIZ, Montreal",
      desc: "DevOps lead & cloud manager. Ran GKE clusters, VMs, Pub/Sub, GCS, and DNS. Built a CI/CD pipeline from scratch to replace a costly third-party service. Deployed full GENAIZ instances end-to-end for clients. Mentored junior devs. Served as interim tech lead during CTO absence.",
    },
    {
      role: "Software Engineer",
      date: "2019 — 2022",
      company: "GENAIZ, Montreal",
      desc: "Built an in-house search engine with a pipeline of dockerized Python microservices. Migrated Node.js monolith to Python microservices architecture. Maintained production data pipelines on GCP. Worked with ML engineers to productionalize AI algorithms.",
    },
    {
      role: "Blockchain Intern → Junior Developer",
      date: "2018 — 2019",
      company: "ubirch GmbH, Berlin → Nancy (remote)",
      desc: "Blockchain-for-IoT startup. Built a mobile app for cryptographic identity verification using Bluetooth BLE. Implemented data anchoring services on IOTA, Ethereum, and MultiChain.",
    },
  ],

  education: [
    {
      role: "MSc Information & Systems Security",
      date: "2018 — 2019",
      company: "Université de Lorraine, Nancy",
    },
    {
      role: "MSc Science & Executive Engineering — CS & IT",
      date: "2016 — 2019",
      company: "Mines de Nancy",
    },
    {
      role: "Classe Préparatoire MPSI/MP (Math, CS, Physics)",
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
