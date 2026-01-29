import from github { Github }
import from datetime { datetime, timedelta, timezone }
import from dotenv { load_dotenv }

import os;
import pandas as pd;

# Data Nodes
node Project {
    has name: str,
        owner: str,
        repo_url: str,
        stars: int = 0,
        last_push: str = "",
        weekly_pushes: int = 0;
}

node User {
    has username: str,
        weekly_pushes: int = 0,
        last_push: str = "",
        avatar_url: str = "";
}

# Walkers
walker LoadData {
    can load_users with `root entry {
        try {
            df = pd.read_csv("data/users.csv");
            for (index, row) in df.iterrows() {
                # Simple check to avoid duplicates for now, can be improved
                already_exists = False;
                for u in [here-->](`?User) {
                    if u.username == row['username'] {
                        already_exists = True;
                        break;
                    }
                }
                if not already_exists {
                    here ++> User(username=row['username']);
                    print(f"Loaded user: {row['username']}");
                }
            }
        } except Exception as e {
            print(f"Error loading users: {e}");
        }
    }

    can load_projects with `root entry {
        try {
            df = pd.read_csv("data/projects.csv");
            for (index, row) in df.iterrows() {
                repo_url = row['repo_url'];  # e.g., "jac-lang/jac"
                parts = repo_url.split("/");

                if len(parts) == 2 {
                    owner = parts[0];
                    name = parts[1];
                    already_exists = False;
                    for p in [here-->](`?Project) {
                        if p.name == name and p.owner == owner {
                            already_exists = True;
                            break;
                        }
                    }
                    if not already_exists {
                        here ++> Project(name=name, owner=owner, repo_url=repo_url);
                        print(f"Loaded project: {repo_url}");
                    }
                }
            }
        } except Exception as e {
            print(f"Error loading projects: {e}");
        }
    }
}

walker UpdateStats {
    has github_token: str = os.environ.get("GITHUB_TOKEN", "");

    can update with `root entry {
        try {
            load_dotenv("../.env");
            self.github_token = os.environ.get("GITHUB_TOKEN", "");
            visit [-->](`?Project);
            visit [-->](`?User);
        } except Exception as e {
            print(f"Error in UpdateStats root: {e}");
        }
    }

    can process_project with Project entry {
        print(f"Updating stats for {here.repo_url}...");
        try {
            g = Github(self.github_token) if self.github_token else Github();
            repo = g.get_repo(here.repo_url);

            here.stars = repo.stargazers_count;

            # Count pushes in the last week
            last_week = datetime.now() - timedelta(days=7);
            commits = repo.get_commits(since=last_week);
            here.weekly_pushes = commits.totalCount;

            here.last_push = str(repo.pushed_at);
            print(
                f"Updated {here.repo_url}: {here.stars} stars, {here.weekly_pushes} pushes"
            );
        } except Exception as e {
            print(f"Failed to update {here.repo_url}: {e}");
        }
    }

    can process_user with User entry {
        print(f"Updating stats for user {here.username}...");
        try {
            g = Github(self.github_token) if self.github_token else Github();
            user = g.get_user(here.username);

            here.avatar_url = user.avatar_url;

            # Count pushes in last week
            last_week = datetime.now(timezone.utc) - timedelta(days=7);
            events = user.get_events();

            push_count = 0;
            latest_push_time = "";

            for event in events {
                if event.created_at < last_week {
                    break;
                }
                if event.type == "PushEvent" {
                    # Count distinct commits in the push
                    payload = event.payload;
                    # PyGithub payload is often a dict or object.
                    # Accessing size safely.
                    size = 1;
                    try {
                        size = payload.size
                        if hasattr(payload, 'size')
                        else payload['size'];
                    } except Exception {
                        size = 1;
                    }
                    push_count += int(size);
                    if latest_push_time == "" {
                        latest_push_time = str(event.created_at);
                    }
                }
            }

            here.weekly_pushes = push_count;
            here.last_push = latest_push_time;

            print(f"Updated user {here.username}: {here.weekly_pushes} pushes");
        } except Exception as e {
            print(f"Failed to update user {here.username}: {e}");
        }
    }
}

def get_time_ago(dt_str: str) -> str {
    if not dt_str {
        return "N/A";
    }
    try {
        dt = pd.to_datetime(dt_str);
        now = datetime.now(timezone.utc);
        if dt.tz is None {
            dt = dt.tz_localize("UTC");
        }

        diff = now - dt;
        seconds = diff.total_seconds();

        if seconds < 60 {
            return f"{int(seconds)} seconds ago";
        }
        minutes = seconds / 60;
        if minutes < 60 {
            return f"{int(minutes)} minutes ago";
        }
        hours = minutes / 60;
        if hours < 24 {
            return f"{int(hours)} hours ago";
        }
        days = hours / 24;
        if days < 30 {
            return f"{int(days)} days ago";
        }
        months = days / 30;
        if months < 12 {
            return f"{int(months)} months ago";
        }
        return f"{int(months / 12)} years ago";
    } except Exception {
        return "N/A";
    }
}

def:pub load_data() {
    root spawn LoadData();
}

def:pub update_stats() {
    root spawn UpdateStats();
}

def:pub get_users() -> list {
    users = [];
    for u in [root-->](`?User) {
        users.append(
            {
                "username": u.username,
                "weekly_pushes": u.weekly_pushes,
                "weekly_pushes": u.weekly_pushes,
                "last_push": get_time_ago(u.last_push),
                "avatar_url": u.avatar_url
            }
        );
    }
    # Bubble sort for safety / Jac syntax compatibility
    n = len(users);
    for i in range(n) {
        for j in range(0, n - i - 1) {
            if users[j]["weekly_pushes"] < users[j + 1]["weekly_pushes"] {
                temp = users[j];
                users[j] = users[j + 1];
                users[j + 1] = temp;
            }
        }
    }
    return users;
}

def:pub get_projects() -> list {
    projects = [];
    for p in [root-->](`?Project) {
        projects.append(
            {
                "name": p.name,
                "owner": p.owner,
                "stars": p.stars,
                "weekly_pushes": p.weekly_pushes,
                "weekly_pushes": p.weekly_pushes,
                "last_push": get_time_ago(p.last_push),
                "repo_url": p.repo_url
            }
        );
    }
    n = len(projects);
    for i in range(n) {
        for j in range(0, n - i - 1) {
            if projects[j]["weekly_pushes"] < projects[j + 1]["weekly_pushes"] {
                temp = projects[j];
                projects[j] = projects[j + 1];
                projects[j + 1] = temp;
            }
        }
    }
    return projects;
}

# Frontend
cl {
    import from react { useEffect, useState }
    import "./global.css";
    import from .components.Button { Button }

    def:pub app() -> any {
        has projects: list = [];
        has users: list = [];
        has loading: bool = False;
        has error: str = "";

        async def fetchData() -> None {
            loading = True;
            try {
                await load_data();
                await update_stats();
                users = await get_users();
                projects = await get_projects();
            } except Exception as e {
                error = str(e);
            }
            loading = False;
        }

        useEffect(lambda -> None { fetchData();setInterval(fetchData, 60000);}, []);

        return
            <div
                style={{
                    display: "flex",
                    flexDirection: "row",
                    height: "100vh",
                    backgroundColor: "#111827",
                    overflow: "hidden"
                }}
            >
                <div
                    style={{
                        flex: 1,
                        backgroundColor: "#1f2937",
                        borderRight: "1px solid #374151",
                        display: "flex",
                        flexDirection: "column"
                    }}
                >
                    <h2
                        style={{
                            padding: "1.5rem",
                            fontSize: "1.5rem",
                            fontWeight: "700",
                            color: "#e5e7eb",
                            borderBottom: "1px solid #374151",
                            margin: 0,
                            textAlign: "center"
                        }}
                    >
                        Top Users
                    </h2>
                    <div
                        className="scroll-container"
                        style={{flex: 1, overflow: "hidden", position: "relative"}}
                    >
                        <div
                            style={{
                                animation: "scrollUp 20s linear infinite",
                                ":hover": {animationPlayState: "paused"}
                            }}
                        >
                            {[
                                <div
                                    key={u["username"]}
                                    style={{
                                        display: "flex",
                                        alignItems: "center",
                                        padding: "1rem",
                                        borderBottom: "1px solid #374151",
                                        gap: "1rem"
                                    }}
                                >
                                    <img
                                        src={u["avatar_url"]}
                                        alt=""
                                        style={{
                                            width: "3rem",
                                            height: "3rem",
                                            borderRadius: "50%"
                                        }}
                                    />
                                    <div style={{flex: 1}}>
                                        <div
                                            style={{
                                                fontWeight: "600",
                                                fontSize: "1.1rem",
                                                color: "#e5e7eb"
                                            }}
                                        >
                                            {u["username"]}
                                        </div>
                                        <div
                                            style={{
                                                fontSize: "0.85rem",
                                                color: "#9ca3af"
                                            }}
                                        >
                                            Last push: {u["last_push"]}
                                        </div>
                                    </div>
                                    <div style={{textAlign: "right"}}>
                                        <div
                                            style={{
                                                fontSize: "1.25rem",
                                                fontWeight: "700",
                                                color: "#10b981"
                                            }}
                                        >
                                            📦 {u["weekly_pushes"]}
                                        </div>
                                    </div>
                                </div> for u in users
                            ]}
                        </div>
                    </div>
                </div>
                <div
                    style={{
                        width: "350px",
                        display: "flex",
                        flexDirection: "column",
                        alignItems: "center",
                        justifyContent: "center",
                        padding: "2rem",
                        backgroundColor: "#111827",
                        zIndex: 10
                    }}
                >
                    <header style={{textAlign: "center", marginBottom: "2rem"}}>
                        <h1
                            style={{
                                fontSize: "2rem",
                                fontWeight: "800",
                                color: "#f9fafb",
                                marginBottom: "0.5rem"
                            }}
                        >
                            GitHub Tracker
                        </h1>
                        <p style={{color: "#9ca3af", fontSize: "1rem"}}>
                            Live activity tracking
                        </p>
                    </header>
                    {<div
                        style={{
                            color: "ef4444",
                            textAlign: "center",
                            padding: "1rem",
                            backgroundColor: "rgba(239,68,68,0.1)",
                            borderRadius: "0.5rem"
                        }}
                    >
                        {error}
                    </div>
                    if error
                    else None}
                    <div
                        style={{
                            marginTop: "2rem",
                            color: "#6b7280",
                            fontSize: "0.85rem"
                        }}
                    >
                        Updates every minute
                    </div>
                </div>
                <div
                    style={{
                        flex: 1,
                        backgroundColor: "#1f2937",
                        borderLeft: "1px solid #374151",
                        display: "flex",
                        flexDirection: "column"
                    }}
                >
                    <h2
                        style={{
                            padding: "1.5rem",
                            fontSize: "1.5rem",
                            fontWeight: "700",
                            color: "#e5e7eb",
                            borderBottom: "1px solid #374151",
                            margin: 0,
                            textAlign: "center"
                        }}
                    >
                        Top Projects
                    </h2>
                    <div
                        className="scroll-container"
                        style={{flex: 1, overflow: "hidden", position: "relative"}}
                    >
                        <div
                            style={{
                                animation: "scrollUp 20s linear infinite",
                                ":hover": {animationPlayState: "paused"}
                            }}
                        >
                            {[
                                <div
                                    key={p["repo_url"]}
                                    style={{
                                        padding: "1rem",
                                        borderBottom: "1px solid #374151"
                                    }}
                                >
                                    <div
                                        style={{
                                            display: "flex",
                                            justifyContent: "space-between",
                                            marginBottom: "0.5rem"
                                        }}
                                    >
                                        <a
                                            href={"https://github.com/" + p["repo_url"]}
                                            target="_blank"
                                            style={{
                                                fontWeight: "600",
                                                fontSize: "1.1rem",
                                                color: "#60a5fa",
                                                textDecoration: "none"
                                            }}
                                        >
                                            {p["owner"]}/{p["name"]}
                                        </a>
                                        <span
                                            style={{
                                                fontSize: "0.9rem",
                                                color: "#d1d5db"
                                            }}
                                        >
                                            ⭐ {p["stars"]}
                                        </span>
                                    </div>
                                    <div
                                        style={{
                                            display: "flex",
                                            justifyContent: "space-between",
                                            alignItems: "center"
                                        }}
                                    >
                                        <span
                                            style={{
                                                fontSize: "0.85rem",
                                                color: "#9ca3af"
                                            }}
                                        >
                                            Last: {p["last_push"]}
                                        </span>
                                        <div
                                            style={{
                                                fontSize: "1.25rem",
                                                fontWeight: "700",
                                                color: "#10b981"
                                            }}
                                        >
                                            📦 {p["weekly_pushes"]}
                                        </div>
                                    </div>
                                </div> for p in projects
                            ]}
                        </div>
                    </div>
                </div>
            </div>;
    }
}
