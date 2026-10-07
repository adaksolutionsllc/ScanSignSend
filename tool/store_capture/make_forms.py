#!/usr/bin/env python3
"""Fictional demo forms for store captures: a one-page rental application.

Born-digital (real text layer), so detection reads labels from the PDF itself.
Every name, address and company in the captures is invented here.

    python3 tool/store_capture/make_forms.py   # -> tool/store_capture/forms/
"""
from __future__ import annotations

import os

from reportlab.lib.colors import HexColor
from reportlab.lib.pagesizes import letter
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "forms")

INK = HexColor("#1B1F24")
MUTED = HexColor("#5B6470")
RULE = HexColor("#3A414A")  # dark enough for rule detection on a render

T = {
    "en": dict(
        file="Rental_Application",
        title="RENTAL APPLICATION",
        sub="Greenfield Residences · Unit 4B",
        s1="APPLICANT DETAILS",
        name="Full name", dob="Date of birth", phone="Phone", email="Email",
        addr="Current address",
        s2="EMPLOYMENT",
        employer="Employer", income="Monthly income", start="Start date",
        s3="HOUSEHOLD",
        pets="I have pets", smoke="Non-smoking household", parking="Parking space needed",
        s4="DECLARATION",
        decl=["I confirm that the information above is true and complete, and I",
              "authorise the landlord to verify it."],
        date="Date", sig="Applicant signature",
    ),
    "fr": dict(
        file="Demande_de_location",
        title="DEMANDE DE LOCATION",
        sub="Résidence Les Tilleuls · Lot 4B",
        s1="CANDIDAT",
        name="Nom complet", dob="Date de naissance", phone="Téléphone", email="E-mail",
        addr="Adresse actuelle",
        s2="EMPLOI",
        employer="Employeur", income="Revenu mensuel", start="Date d'embauche",
        s3="FOYER",
        pets="J'ai des animaux", smoke="Foyer non-fumeur", parking="Place de parking souhaitée",
        s4="DÉCLARATION",
        decl=["Je certifie que les informations ci-dessus sont exactes et complètes",
              "et j'autorise le bailleur à les vérifier."],
        date="Date", sig="Signature du candidat",
    ),
    "es": dict(
        file="Solicitud_de_alquiler",
        title="SOLICITUD DE ALQUILER",
        sub="Residencial Los Álamos · Depto. 4B",
        s1="DATOS DEL SOLICITANTE",
        name="Nombre completo", dob="Fecha de nacimiento", phone="Teléfono", email="Correo",
        addr="Domicilio actual",
        s2="EMPLEO",
        employer="Empresa", income="Ingreso mensual", start="Fecha de ingreso",
        s3="HOGAR",
        pets="Tengo mascotas", smoke="Hogar sin fumadores", parking="Necesito estacionamiento",
        s4="DECLARACIÓN",
        decl=["Declaro que la información anterior es verdadera y completa, y",
              "autorizo al arrendador a verificarla."],
        date="Fecha", sig="Firma del solicitante",
    ),
    "pt": dict(
        file="Ficha_de_locacao",
        title="FICHA DE LOCAÇÃO",
        sub="Residencial Jardim das Flores · Apto. 4B",
        s1="DADOS DO LOCATÁRIO",
        name="Nome completo", dob="Data de nascimento", phone="Telefone", email="E-mail",
        addr="Endereço atual",
        s2="EMPREGO",
        employer="Empregador", income="Renda mensal", start="Data de admissão",
        s3="MORADORES",
        pets="Tenho animais", smoke="Não fumantes", parking="Preciso de vaga na garagem",
        s4="DECLARAÇÃO",
        decl=["Declaro que as informações acima são verdadeiras e completas e",
              "autorizo o locador a verificá-las."],
        date="Data", sig="Assinatura do locatário",
    ),
}

pdfmetrics.registerFont(
    TTFont("ArialUnicode", "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"))

W, H = letter
M = 64  # page margin


def blank(c: canvas.Canvas, x: float, y: float, label: str, x_end: float) -> None:
    """`Label: ________` — a label followed by a rule to [x_end]."""
    c.setFont("Helvetica", 10.5)
    c.setFillColor(INK)
    c.drawString(x, y, f"{label}:")
    lx = x + c.stringWidth(f"{label}:", "Helvetica", 10.5) + 6
    c.setStrokeColor(RULE)
    c.setLineWidth(0.9)
    c.line(lx, y - 2, x_end, y - 2)


def section(c: canvas.Canvas, y: float, text: str) -> None:
    c.setFont("Helvetica-Bold", 10)
    c.setFillColor(MUTED)
    c.drawString(M, y, text)
    c.setStrokeColor(HexColor("#D5DAE0"))
    c.setLineWidth(0.6)
    c.line(M, y - 5, W - M, y - 5)


def checkbox(c: canvas.Canvas, x: float, y: float, label: str) -> None:
    # A real ☐ glyph in the text layer, as digital forms have, not a drawn box.
    c.setFont("ArialUnicode", 12)
    c.setFillColor(INK)
    c.drawString(x, y - 1, "☐")
    c.setFont("Helvetica", 10.5)
    c.drawString(x + 16, y, label)


def make(lang: str, t: dict) -> str:
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f"{t['file']}.pdf")
    c = canvas.Canvas(path, pagesize=letter)
    c.setTitle(t["title"].title())
    c.setAuthor("Scan Sign Send demo")

    y = H - 84
    c.setFont("Helvetica-Bold", 18)
    c.setFillColor(INK)
    c.drawCentredString(W / 2, y, t["title"])
    c.setFont("Helvetica", 10)
    c.setFillColor(MUTED)
    c.drawCentredString(W / 2, y - 17, t["sub"])

    mid = W / 2 + 8
    y -= 58
    section(c, y, t["s1"])
    y -= 30
    blank(c, M, y, t["name"], W - M)
    y -= 30
    blank(c, M, y, t["dob"], mid - 16)
    blank(c, mid, y, t["phone"], W - M)
    y -= 30
    blank(c, M, y, t["email"], W - M)
    y -= 30
    blank(c, M, y, t["addr"], W - M)

    y -= 46
    section(c, y, t["s2"])
    y -= 30
    blank(c, M, y, t["employer"], W - M)
    y -= 30
    blank(c, M, y, t["income"], mid - 16)
    blank(c, mid, y, t["start"], W - M)

    y -= 46
    section(c, y, t["s3"])
    y -= 28
    checkbox(c, M, y, t["pets"])
    checkbox(c, mid, y, t["smoke"])
    y -= 24
    checkbox(c, M, y, t["parking"])

    y -= 46
    section(c, y, t["s4"])
    y -= 24
    c.setFont("Helvetica", 10.5)
    c.setFillColor(INK)
    for line in t["decl"]:
        c.drawString(M, y, line)
        y -= 15

    y -= 34
    blank(c, M, y, t["sig"], M + 330)
    y -= 34
    blank(c, M, y, t["date"], M + 200)

    c.showPage()
    c.save()
    return path


if __name__ == "__main__":
    for lang, t in T.items():
        print(make(lang, t))
