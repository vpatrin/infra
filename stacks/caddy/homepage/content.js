const ICONS = {
  telegram: '<svg class="link-icon" viewBox="0 0 24 24" fill="currentColor"><path d="M11.944 0A12 12 0 0 0 0 12a12 12 0 0 0 12 12 12 12 0 0 0 12-12A12 12 0 0 0 12 0a12 12 0 0 0-.056 0zm4.962 7.224c.1-.002.321.023.465.14a.506.506 0 0 1 .171.325c.016.093.036.306.02.472-.18 1.898-.962 6.502-1.36 8.627-.168.9-.499 1.201-.82 1.23-.696.065-1.225-.46-1.9-.902-1.056-.693-1.653-1.124-2.678-1.8-1.185-.78-.417-1.21.258-1.91.177-.184 3.247-2.977 3.307-3.23.007-.032.014-.15-.056-.212s-.174-.041-.249-.024c-.106.024-1.793 1.14-5.061 3.345-.48.33-.913.49-1.302.48-.428-.008-1.252-.241-1.865-.44-.752-.245-1.349-.374-1.297-.789.027-.216.325-.437.893-.663 3.498-1.524 5.83-2.529 6.998-3.014 3.332-1.386 4.025-1.627 4.476-1.635z"/></svg>',
  globe: '<svg class="link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>',
  terminal: '<svg class="link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/></svg>',
  github: '<svg class="link-icon" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z"/></svg>',
  download: '<svg class="link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>',
  linkedin: '<svg class="link-icon" viewBox="0 0 24 24" fill="currentColor"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 0 1-2.063-2.065 2.064 2.064 0 1 1 2.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/></svg>',
  email: '<svg class="link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>',
};

const content = {
  name: "Victor",
  surname: "Patrin",
  tagline: "backend, infra & AI · montreal",

  links: [
    { label: "github", url: "https://github.com/vpatrin", icon: ICONS.github },
    { label: "linkedin", url: "https://www.linkedin.com/in/victorpatrin/", icon: ICONS.linkedin },
    { label: "email", url: "mailto:victor.patrin@protonmail.com", icon: ICONS.email },
    { label: "resume", url: "resume.pdf", icon: ICONS.download },
  ],

  availability: "open to senior eng roles — remote worldwide",

  summary: [
    "Senior Software Engineer who ships entire products — backend, data pipelines, infrastructure, CI/CD, and AI integration. 6 years at an early-stage AI startup, progressing from intern to leading engineering and reporting directly to the CEO",
    "Building and deploying everything from bare-metal Kubernetes clusters to RAG pipelines to client-facing applications",
  ],

  projects: [
    {
      name: "coupette",
      status: "live",
      desc: [
        "AI sommelier for Quebec's SAQ catalog — bilingual (FR/EN) wine recommendations via a React frontend, a Telegram bot, and a FastAPI backend (PostgreSQL + pgvector)",
        "Hybrid RAG pipeline: Claude intent routing → SQL filters → pgvector similarity → MMR re-ranking → Claude Haiku curation",
        "LLM eval framework with a 5-dimension rubric and Claude Sonnet as judge — tracked quality improvement from 3.37 → 4.05/5",
        "Multi-source scraper (SAQ sitemap, BeautifulSoup, Adobe Live Search) with robots.txt compliance",
      ],
      stack: "FastAPI / PostgreSQL + pgvector / Claude API / React / Docker",
      links: [
        { label: "github", url: "https://github.com/vpatrin/coupette", icon: ICONS.github },
        { label: "telegram", url: "https://t.me/AlerteVinBot", icon: ICONS.telegram },
        { label: "web", url: "https://coupette.club", icon: ICONS.globe },
      ],
    },
    {
      name: "infra",
      status: "live",
      desc: [
        "Full production platform behind coupette.club — IaC end-to-end: Terraform (DNS, firewall), Ansible (server configuration, CIS hardening), disaster recovery runbook for full redeployment from scratch",
        "Grafana/Loki/Prometheus observability stack + automated PostgreSQL backups to S3 (30-day retention)",
        "CIS/ANSSI hardening (Lynis 80/100, testssl.sh A+), container hardening (cap_drop, read-only fs, no-new-privileges), secret management (sops/age)",
      ],
      stack: "Terraform / Ansible / Docker / Caddy / Grafana · Loki · Prometheus",
      links: [
        { label: "github", url: "https://github.com/vpatrin/infra", icon: ICONS.github },
      ],
    },
  ],

  experience: [
    {
      role: "Senior Software Engineer",
      date: "Sep 2022 — Aug 2025",
      company: "GENAIZ, Montreal",
      tagline: "AI-powered automation platform for life sciences, serving enterprise pharma clients",
      desc: [
        "Led engineering after the CTO's departure — ran sprint planning, product meetings, and daily standups, reported directly to the CEO, and coordinated delivery across a 4-person team",
        "Saved ~$20K/year in licensing costs by building a custom Continuous Deployment system (GitLab CI + Helm) to replace Harness CD",
        "Slashed cloud infrastructure costs by 50% (~$9K/year) by leading a GCP audit, decommissioning idle assets, and migrating from managed cloud storage to a self-hosted NFS server on Kubernetes",
        "Owned all GCP infrastructure across 5 Kubernetes clusters (on GKE: dev/staging, prod, 2 dedicated client environments; on a bare-metal cluster for demos), running 15+ microservices — provisioning, scaling, health monitoring, and release coordination",
        "Deployed the full GENAIZ platform for 3 enterprise pharma clients and built an on-premises bare-metal cluster from scratch for client demos, replacing a dedicated GKE environment",
        "Part of the quality team leading CFR 21 Part 11 compliance — edited company security policies, drove compliance sprints (audit trails, access controls), and owned policy documentation",
      ],
    },
    {
      role: "Software Engineer",
      date: "Oct 2019 — Sep 2022",
      company: "GENAIZ, Montreal",
      desc: [
        "Bridged ML research and production — worked with ML engineers to productionalize AI algorithms for pharma clients, including wrapping the NLP pipeline (tokenizer, doc2vec) into Dockerized Python microservices and integrating them into Vespa search",
        "Reworked ETL pipelines to normalize unstructured pharma documents into a standard format, enabling downstream AI features",
        "Drove migration of a Node.js monolith into ~8 Python microservices, enabling independent deployment and scaling per service",
      ],
    },
    {
      role: "Blockchain Intern",
      date: "Apr — Oct 2019",
      company: "GENAIZ, Montreal",
      desc: ["Built an immutable audit trail anchoring event log hashes to Bitcoin transactions for tamper-proof verification"],
    },
    {
      role: "Junior Developer",
      date: "Jun 2018 — Mar 2019",
      company: "ubirch GmbH, Berlin",
      tagline: "Blockchain-for-IoT startup",
      desc: ["Built a mobile app for cryptographic identity verification over Bluetooth BLE and implemented data anchoring on IOTA, Ethereum, and MultiChain networks"],
    },
  ],

  education: [
    { role: "M.Sc. Information & Systems Security", date: "2018 — 2019", company: "Université de Lorraine, France" },
    { role: "Diplôme d'Ingénieur (M.Eng.)", date: "2016 — 2019", company: "Mines de Nancy, France" },
    { role: "Classe Préparatoire MPSI/MP", date: "2013 — 2016", company: "Lycée Gay-Lussac, France" },
  ],

  interests: 'Ultra-endurance cycling · Wine tasting (<a href="https://www.wsetglobal.com/qualifications/wset-level-3-award-in-wines/" target="_blank" rel="noopener">WSET Level 3</a> candidate) · Philosophy',

  footer: "made with too much coffee",
};
