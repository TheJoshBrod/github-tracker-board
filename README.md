# GitHub Activity Tracker

A real-time dashboard built with **Jac** to track GitHub user activity (weekly pushes) and project statistics (stars, star history, push frequency).

## Features
- **Live Dashboard**: Auto-refreshing UI with a dark mode aesthetic.
- **User Tracking**: Monitor weekly pushes and last query times for specific users.
- **Project Tracking**: Track repository stars and pushes.
- **Star History Graph**: Visualizes star growth over time for top projects.
- **CSV Configuration**: Easily manage the list of tracked entities via CSV files.

## Prerequisites
- Python 3.12+
- [Jac Language](https://github.com/jaseci-labs/jaclang)

## Setup

1.  **Clone the repository**:
    ```bash
    git clone <repository-url>
    cd github-tracker/github-tracker
    ```

2. **Install Jac**
    You will need to install `jaseci`
    ```bash
    python -m venv env
    source env/bin/activate
    pip install jaseci
    ```

2.  **Install Dependencies**:
    You will need `PyGithub`, `pandas`, and `python-dotenv` in your jac enviornment.
    ```bash
    jac add PyGithub pandas python-dotenv
    ```

3.  **Environment Variables**:
    Create a `.env` file in the project root (one level up or in the same directory) containing your GitHub Personal Access Token to avoid rate limiting.
    ```bash
    GITHUB_TOKEN=your_github_token_here
    ```

## Configuration

Control the data being tracked by editing the files in the `data/` directory:

- **`data/users.csv`**:
    ```csv
    username
    jaseci-labs
    thejoshbrod
    ```

- **`data/projects.csv`**:
    ```csv
    repo_url
    jac-lang/jac
    ```

The application automatically syncs with these files on startup.

## Running the Application

Start the Jac development server:

```bash
jac start main.jac
```

Open your browser to `http://localhost:8000` (or the port specified in the console) to view the dashboard.
