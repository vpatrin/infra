const ICONS = {
  telegram: '<svg class="link-icon" viewBox="0 0 24 24" fill="currentColor"><path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z"/></svg>',
  globe: '<svg class="link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>',
  terminal: '<svg class="link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/></svg>',
  github: '<svg class="link-icon" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z"/></svg>',
};

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
      name: "saq-sommelier",
      status: "live",
      desc: "AI wine discovery engine for Quebec's 15,000+ SAQ wines. Telegram bot live, web app and SSH TUI coming. One FastAPI backend, multiple clients.",
      stack: "FastAPI / PostgreSQL / python-telegram-bot / Docker",
      links: [
        { label: "github", url: "https://github.com/vpatrin/saq-sommelier", icon: ICONS.github },
        { label: "telegram", url: "https://t.me/AlerteVinBot", icon: ICONS.telegram },
        { label: "web", soon: true, icon: ICONS.globe },
        { label: "ssh", soon: true, icon: ICONS.terminal },
      ],
    },
    {
      name: "ssh-resume",
      status: "soon",
      desc: "Interactive resume accessible over SSH — browse experience, projects, and stack from your terminal",
      stack: "Go / Bubbletea / Wish",
      links: [
        { label: "ssh", soon: true, icon: ICONS.terminal },
      ],
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
