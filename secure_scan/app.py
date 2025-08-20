from flask import Flask, render_template, request, redirect, url_for, send_from_directory
import subprocess
import os
import uuid
import glob

app = Flask(__name__)
RESULTS_DIR = "scan_results"
os.makedirs(RESULTS_DIR, exist_ok=True)

@app.route("/")
def index():
    reports = sorted(
        glob.glob(f"{RESULTS_DIR}/report_*.html"),
        key=os.path.getctime,
        reverse=True
    )
    recent = [os.path.basename(r) for r in reports[:5]]
    return render_template("index.html", recent=recent)

@app.route("/scan", methods=["POST"])
def scan():
    target = request.form.get("target").strip()
    if not target:
        return "Target required", 400
    scan_id = str(uuid.uuid4())[:8]
    log_file = f"{RESULTS_DIR}/{target}_{scan_id}.log"
    cmd = ["./secure_scan.sh", target]
    with open(log_file, "w") as f:
        subprocess.Popen(cmd, stdout=f, stderr=f)
    return redirect(url_for("status", target=target, scan_id=scan_id))

@app.route("/status/<target>/<scan_id>")
def status(target, scan_id):
    return f"<h2>✅ Сканирование {target} запущено (ID: {scan_id})</h2><p>Результаты: <a href='/results'>Посмотреть отчёты</a></p>"

@app.route("/results")
def results():
    files = [f for f in os.listdir(RESULTS_DIR) if f.startswith("report_")]
    return "<h2>Доступные отчёты</h2><ul>" + \
           "".join(f"<li><a href='/download/{f}'>{f}</a></li>" for f in files) + \
           "</ul>"

@app.route("/download/<path:filename>")
def download(filename):
    return send_from_directory(RESULTS_DIR, filename)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)