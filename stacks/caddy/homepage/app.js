document.getElementById("hero").innerHTML = `
    <div class="hero">
        <div class="hero-left">
            <h1 class="hero-name">${content.name} <span>${content.surname}</span></h1>
            <nav class="hero-links">
                ${content.links.map(l =>
                    `<a href="${l.url}" data-umami-event="click-${l.label}" ${l.url.startsWith("mailto:") ? "" : 'target="_blank" rel="noopener"'}>${l.icon ? l.icon + " " : ""}${l.label}</a>`
                ).join("")}
            </nav>
            <div class="hero-tagline">${content.tagline}</div>
            <div class="hero-tagline hero-tagline-availability">${content.availability}<span class="cursor"></span></div>
        </div>
    </div>
`;

document.getElementById("about-section").innerHTML = `
    <h2>About</h2>
    <div class="summary">
        ${content.summary.map(p => `<p><span class="summary-prompt">&gt;</span>${p}</p>`).join("")}
    </div>
`;

document.getElementById("projects-section").innerHTML = `
    <h2>Projects</h2>
    ${content.projects.map(p => `
        <div class="project" data-umami-event="project-view" data-umami-event-project="${p.name}">
            <div class="project-header">
                <div class="project-header-left">
                    <span class="project-name">${p.name}</span>
                    <div class="project-header-links">
                        ${(p.links || []).map(l =>
                            `<a class="project-link" href="${l.url}" data-umami-event="project-click-${p.name}-${l.label}" target="_blank" rel="noopener">${l.icon || ""}${l.label}</a>`
                        ).join("")}
                    </div>
                </div>
                <span class="project-status ${p.status}">${p.status}</span>
            </div>
            ${Array.isArray(p.desc)
                ? `<ul class="project-bullets">${p.desc.map(b => `<li>${b}</li>`).join("")}</ul>`
                : `<div class="project-desc">${p.desc}</div>`
            }
            <div class="project-stack">${p.stack}</div>
        </div>
    `).join("")}
`;

document.getElementById("experience-section").innerHTML = `
    <h2>Experience</h2>
    ${content.experience.map(e => `
        <div class="exp-item">
            <div class="exp-header">
                <span class="exp-role">${e.role}</span>
                <span class="exp-date">${e.date}</span>
            </div>
            <div class="exp-company">${e.company}</div>
            ${e.tagline ? `<div class="exp-tagline">${e.tagline}</div>` : ""}
            ${Array.isArray(e.desc)
                ? `<ul class="exp-bullets">${e.desc.map(b => `<li>${b}</li>`).join("")}</ul>`
                : `<div class="exp-desc">${e.desc}</div>`
            }
        </div>
    `).join("")}
`;

document.getElementById("education-section").innerHTML = `
    <h2>Education</h2>
    ${content.education.map(e => `
        <div class="edu-item">
            <div>
                <div class="edu-role">${e.role}</div>
                <div class="edu-company">${e.company}</div>
            </div>
            <span class="edu-date">${e.date}</span>
        </div>
    `).join("")}
`;

document.getElementById("interests-section").innerHTML = `
    <h2>Interests</h2>
    <div class="interests">${content.interests}</div>
`;

document.getElementById("footer").innerHTML = `
    <span>${content.footer}</span>
`;
