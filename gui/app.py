"""Interfaz grafica de latent (solo interfaz).

Python NO procesa la imagen: elige el archivo, manda el texto PGM al
servidor Haskell por un socket TCP, recibe la respuesta y la muestra.
Todos los filtros, la compresion y la validacion viven en Haskell.

El archivo esta en cuatro partes:
1. Tema: colores, tipografia y tamanos.
2. Cliente del protocolo: hablar con Haskell.
3. Tarjetas: piezas visuales reutilizables.
4. App: arma la ventana y responde a los botones.
"""
import socket
import time
import tkinter as tk
from tkinter import filedialog, font

# ---------------------------------------------------------------- 1. Tema

HOST, PORT = "127.0.0.1", 5000
VIEW_SIZE = 400  # lado del area donde se dibuja cada imagen, en pixeles

BACKGROUND = "#F4F4F5"
CARD = "#FFFFFF"
BORDER = "#E4E4E7"
TEXT = "#18181B"
MUTED = "#71717A"   # etiquetas chicas; contraste 4.8 a 1 sobre blanco
ACCENT = "#2563EB"  # unico acento; contraste 5.2 a 1 con texto blanco
ACCENT_HOVER = "#1D4ED8"
ERROR = "#B91C1C"
DISABLED = "#A1A1AA"


def make_fonts():
    """Elige la primera familia instalada y define la escala de tamanos."""
    installed = set(font.families())
    family = next((f for f in ("Inter", "Ubuntu", "Noto Sans", "DejaVu Sans") if f in installed), "TkDefaultFont")
    mono = next((f for f in ("Ubuntu Mono", "DejaVu Sans Mono") if f in installed), "TkFixedFont")
    return {
        "title": (family, 18, "bold"),
        "heading": (family, 13, "bold"),
        "body": (family, 11),
        "small": (family, 9),
        "pill": (family, 9, "bold"),
        "big": (family, 34, "bold"),
        "mono": (mono, 11),
    }


# ---------------------------------------------------- 2. Cliente del protocolo

class ServerError(Exception):
    """Haskell respondio ERROR: el mensaje viene del servidor."""


def ask_server(command, pgm_text):
    """Manda 'comando + PGM' a Haskell y regresa (tipo, cuerpo) de la respuesta.

    Lanza OSError si el servidor no esta corriendo y ServerError si Haskell
    rechazo la peticion.
    """
    with socket.create_connection((HOST, PORT), timeout=10) as conn:
        conn.sendall((command + "\n" + pgm_text).encode("ascii"))
        conn.shutdown(socket.SHUT_WR)  # avisa a Haskell que ya terminamos de mandar
        chunks = []
        while chunk := conn.recv(65536):
            chunks.append(chunk)
    kind, _, body = b"".join(chunks).decode("ascii").partition("\n")
    if kind.startswith("ERROR"):
        raise ServerError(kind.removeprefix("ERROR").strip())
    return kind, body


def parse_stats(body):
    """Convierte las lineas 'clave valor' de STATS en un diccionario de textos."""
    return dict(line.split(" ", 1) for line in body.splitlines() if " " in line)


def p2_to_photo(pgm_text):
    """Convierte P2 (texto) a P5 (binario) SOLO para mostrarlo.

    Esto NO es un filtro: los valores de los pixeles no cambian, solo se
    escriben como bytes, porque PhotoImage de Tk no lee P2 de texto.
    Regresa la imagen lista para la pantalla y su ancho y alto reales.
    """
    lines = [line for line in pgm_text.splitlines() if not line.startswith("#")]
    tokens = " ".join(lines).split()
    width, height = int(tokens[1]), int(tokens[2])
    header = f"P5\n{width} {height}\n255\n".encode("ascii")
    photo = tk.PhotoImage(data=header + bytes(int(t) for t in tokens[4:]))
    # Ajuste de tamano en pantalla: ampliar las chicas, reducir las grandes
    side = max(width, height)
    if side > VIEW_SIZE:
        photo = photo.subsample(-(-side // VIEW_SIZE))  # division hacia arriba
    elif side * 2 <= VIEW_SIZE:
        photo = photo.zoom(VIEW_SIZE // side)
    return photo, width, height


# ------------------------------------------------------------ 3. Tarjetas

def make_button(parent, text, command, fonts, primary=False):
    """Boton plano: el primario lleva el acento; los demas son neutros y
    contrastan con su superficie (blancos sobre el fondo, grises en tarjetas)."""
    if primary:
        background, hover = ACCENT, ACCENT_HOVER
    elif parent.cget("bg") == BACKGROUND:
        background, hover = CARD, BORDER
    else:
        background, hover = BACKGROUND, BORDER
    return tk.Button(
        parent, text=text, command=command, font=fonts["body"],
        bg=background, fg="white" if primary else TEXT,
        activebackground=hover, activeforeground="white" if primary else TEXT,
        disabledforeground=DISABLED, relief="flat", bd=0, highlightthickness=0,
        padx=14, pady=7, cursor="hand2",
    )


def make_entry(parent, fonts, default, width):
    """Campo de texto plano con borde que se pinta del acento al enfocarlo."""
    entry = tk.Entry(
        parent, width=width, font=fonts["mono"], relief="flat", bg=CARD, fg=TEXT,
        insertbackground=TEXT, highlightthickness=1, highlightbackground=BORDER,
        highlightcolor=ACCENT,
    )
    entry.insert(0, default)
    return entry


class Card(tk.Frame):
    """Tarjeta del sistema: titulo a la izquierda y pastilla negra a la derecha."""

    def __init__(self, parent, title, fonts):
        super().__init__(parent, bg=CARD, highlightthickness=1, highlightbackground=BORDER)
        self.fonts = fonts
        header = tk.Frame(self, bg=CARD)
        header.pack(fill="x", padx=18, pady=(16, 10))
        tk.Label(header, text=title, font=fonts["heading"], bg=CARD, fg=TEXT).pack(side="left")
        self.pill = tk.Label(header, font=fonts["pill"], bg=TEXT, fg="white", padx=10, pady=3)
        self.body = tk.Frame(self, bg=CARD)
        self.body.pack(fill="both", expand=True, padx=18, pady=(0, 18))

    def set_pill(self, text):
        """Muestra la pastilla con el texto dado, o la oculta si no hay texto."""
        if text:
            self.pill.configure(text=text)
            self.pill.pack(side="right")
        else:
            self.pill.pack_forget()

    def label(self, parent, text, kind="body", color=TEXT):
        """Etiqueta con el fondo de la tarjeta, para no repetir opciones."""
        return tk.Label(parent, text=text, font=self.fonts[kind], bg=CARD, fg=color, anchor="w", justify="left")


class ImageCard(Card):
    """Responde: ¿como se ve la imagen? El area es fija para que nada salte."""

    def __init__(self, parent, title, empty_text, fonts):
        super().__init__(parent, title, fonts)
        area = tk.Frame(self.body, bg=BACKGROUND, width=VIEW_SIZE, height=VIEW_SIZE)
        area.pack()
        area.pack_propagate(False)
        self.picture = tk.Label(area, bg=BACKGROUND, fg=MUTED, font=fonts["body"], text=empty_text)
        self.picture.pack(expand=True)
        self.caption = self.label(self.body, "", "small", MUTED)
        self.caption.pack(fill="x", pady=(10, 0))
        self.empty_text = empty_text

    def show(self, pgm_text, caption):
        photo, width, height = p2_to_photo(pgm_text)
        self.picture.configure(image=photo, text="")
        self.picture.image = photo  # guardar referencia para que Tk no la borre
        self.caption.configure(text=caption)
        self.set_pill(f"{width} × {height} px")

    def clear(self):
        self.picture.configure(image="", text=self.empty_text)
        self.picture.image = None
        self.caption.configure(text="")
        self.set_pill("")


class CompressionCard(Card):
    """Responde: ¿cuanto ocupa la imagen comprimida con RLE?

    Va en horizontal: porcentaje a la izquierda, detalle al centro y el
    boton a la derecha, junto al resultado que produce.
    """

    BAR_WIDTH = 260
    EMPTY_TEXT = "Comprime la imagen para ver cuánto ocupa"

    def __init__(self, parent, on_compress, fonts):
        super().__init__(parent, "Compresión RLE", fonts)
        self.body.columnconfigure(1, weight=1)
        summary = tk.Frame(self.body, bg=CARD)
        summary.grid(row=0, column=0, sticky="w", padx=(0, 32))
        self.percent = self.label(summary, "", "big")
        self.caption = self.label(summary, self.EMPTY_TEXT, "small", MUTED)
        self.caption.pack(side="bottom", fill="x")
        self.details = tk.Frame(self.body, bg=CARD)
        self.button = make_button(self.body, "Comprimir", on_compress, fonts)
        self.button.grid(row=0, column=2, sticky="e")

    def show(self, stats):
        percent = int(stats["percent"])
        self.percent.configure(text=f"{percent} %")
        self.percent.pack(side="top", fill="x")
        self.caption.configure(text="del tamaño original")
        for child in self.details.winfo_children():
            child.destroy()
        # Barra de avance: el largo es el porcentaje que calculo Haskell (tope 100)
        bar = tk.Canvas(self.details, width=self.BAR_WIDTH, height=8, bg=CARD, highlightthickness=0)
        bar.create_rectangle(0, 0, self.BAR_WIDTH, 8, fill=BORDER, width=0)
        bar.create_rectangle(0, 0, self.BAR_WIDTH * min(percent, 100) // 100, 8, fill=ACCENT, width=0)
        bar.grid(row=0, column=0, columnspan=3, sticky="w", pady=(0, 10))
        values = [("original", f"{stats['originalSize']} enteros"),
                  ("comprimida", f"{stats['compressedSize']} enteros"),
                  ("rachas", stats["runs"])]
        for column, (name, value) in enumerate(values):
            self.label(self.details, name, "small", MUTED).grid(row=1, column=column, sticky="w", padx=(0, 28))
            self.label(self.details, value).grid(row=2, column=column, sticky="w", padx=(0, 28))
        self.details.grid(row=0, column=1, sticky="w")
        self.set_pill("sin pérdida ✓" if stats["roundTrip"] == "True" else "con pérdida ✕")

    def clear(self):
        self.percent.pack_forget()
        self.caption.configure(text=self.EMPTY_TEXT)
        self.details.grid_forget()
        self.set_pill("")


# ------------------------------------------------------------------ 4. App

class App:
    def __init__(self, root):
        self.root = root
        self.fonts = make_fonts()
        self.file_text = None   # PGM del archivo abierto, ya validado por Haskell
        self.source = None      # PGM al que se le aplican los filtros
        self.result = None      # ultimo PGM que regreso Haskell
        self.file_name = ""

        root.title("latent")
        root.configure(bg=BACKGROUND)
        self.build_top_bar()
        self.build_body()
        root.bind("<Control-o>", lambda _: self.open_file())
        root.bind("<Control-s>", lambda _: self.save_file())
        self.refresh_controls()

    # ---- construccion de la ventana

    def build_top_bar(self):
        bar = tk.Frame(self.root, bg=BACKGROUND)
        bar.pack(fill="x", padx=24, pady=(20, 6))
        titles = tk.Frame(bar, bg=BACKGROUND)
        titles.pack(side="left")
        tk.Label(titles, text="latent", font=self.fonts["title"], bg=BACKGROUND, fg=TEXT).pack(anchor="w")
        tk.Label(titles, text="Filtros y compresión de imágenes PGM, calculados en Haskell",
                 font=self.fonts["small"], bg=BACKGROUND, fg=MUTED).pack(anchor="w")

        self.open_button = make_button(bar, "Abrir PGM", self.open_file, self.fonts, primary=True)
        self.save_button = make_button(bar, "Guardar resultado", self.save_file, self.fonts)
        self.continue_button = make_button(bar, "Seguir desde el resultado", self.continue_from_result, self.fonts)
        self.reset_button = make_button(bar, "Volver al archivo", self.reset_to_file, self.fonts)
        for button in (self.open_button, self.save_button, self.continue_button, self.reset_button):
            button.pack(side="right", padx=(8, 0))

        self.status = tk.Label(self.root, text="Abre un archivo PGM P2 para empezar", font=self.fonts["body"],
                               bg=BACKGROUND, fg=MUTED, anchor="w")
        self.status.pack(fill="x", padx=24, pady=(4, 12))

    def build_body(self):
        body = tk.Frame(self.root, bg=BACKGROUND)
        body.pack(fill="both", expand=True, padx=24, pady=(0, 24))

        self.build_filters(body)

        main = tk.Frame(body, bg=BACKGROUND)
        main.pack(side="left", anchor="n", padx=(16, 0))
        images = tk.Frame(main, bg=BACKGROUND)
        images.pack(fill="x")
        self.original_card = ImageCard(images, "Original", "Abre un archivo PGM", self.fonts)
        self.result_card = ImageCard(images, "Resultado", "Elige un filtro", self.fonts)
        self.original_card.pack(side="left")
        self.result_card.pack(side="left", padx=(16, 0))
        self.compression = CompressionCard(main, self.compress, self.fonts)
        self.compression.pack(fill="x", pady=(16, 0))

    def build_filters(self, parent):
        """Responde: ¿que le hago a la imagen? Agrupa los filtros por tipo."""
        card = Card(parent, "Filtros", self.fonts)
        card.pack(side="left", anchor="n")
        self.filter_buttons = []

        def section(name):
            card.label(card.body, name, "small", MUTED).pack(fill="x", pady=(10, 4))
            row = tk.Frame(card.body, bg=CARD)
            row.pack(fill="x")
            return row

        def button(row, text, command, cell=None):
            b = make_button(row, text, command, self.fonts)
            if cell is None:
                b.pack(side="left", fill="x", expand=True)
            else:
                b.grid(row=cell // 2, column=cell % 2, sticky="ew", padx=2, pady=2)
            self.filter_buttons.append(b)

        def with_value(name, label, default):
            row = section(label)
            entry = make_entry(row, self.fonts, default, 6)
            entry.pack(side="left", padx=(0, 8), ipady=5)
            button(row, f"Aplicar {label}", lambda: self.apply(f"{name} {entry.get().strip()}"))
            entry.bind("<Return>", lambda _: self.apply(f"{name} {entry.get().strip()}"))

        button(section("tono"), "Negativo", lambda: self.apply("negative"))
        with_value("brightness", "brillo", "40")
        with_value("threshold", "umbral", "128")

        grid = section("geometría")
        grid.columnconfigure((0, 1), weight=1)
        for cell, (text, command) in enumerate([("Espejo horizontal", "mirrorHorizontal"),
                                                 ("Espejo vertical", "mirrorVertical"),
                                                 ("Rotar a la derecha", "rotateRight"),
                                                 ("Rotar a la izquierda", "rotateLeft")]):
            button(grid, text, lambda c=command: self.apply(c), cell)

        button(section("suavizado"), "Desenfoque 3x3", lambda: self.apply("blur"))

        chain_row = section("cadena, de izquierda a derecha")
        self.chain_entry = make_entry(chain_row, self.fonts, "brightness:30,rotateRight,threshold:128", 30)
        self.chain_entry.pack(fill="x", ipady=5)
        self.chain_entry.bind("<Return>", lambda _: self.apply_chain())
        chain_button_row = tk.Frame(card.body, bg=CARD)
        chain_button_row.pack(fill="x", pady=(6, 0))
        button(chain_button_row, "Aplicar cadena", self.apply_chain)

    # ---- estado de la interfaz

    def refresh_controls(self):
        """Activa solo lo que tiene sentido ahora, para prevenir errores."""
        def enable(widget, condition):
            widget.configure(state="normal" if condition else "disabled")

        for b in self.filter_buttons:
            enable(b, self.source is not None)
        enable(self.compression.button, self.source is not None)
        enable(self.save_button, self.result is not None)
        enable(self.continue_button, self.result is not None)
        enable(self.reset_button, self.file_text is not None and self.source != self.file_text)

    def set_status(self, text, error=False):
        self.status.configure(text=("✕  " if error else "✓  ") + text, fg=ERROR if error else TEXT)

    def request(self, command, pgm_text):
        """Pide algo a Haskell. Regresa (tipo, cuerpo, ms) o None si fallo."""
        start = time.perf_counter()
        try:
            kind, body = ask_server(command, pgm_text)
        except ServerError as error:
            self.set_status(f"Haskell rechazó la petición: {error}", error=True)
            return None
        except OSError:
            self.set_status("Sin conexión con Haskell. Arranca el servidor con ./run.sh", error=True)
            return None
        return kind, body, round((time.perf_counter() - start) * 1000)

    # ---- acciones

    def open_file(self):
        path = filedialog.askopenfilename(filetypes=[("Imágenes PGM", "*.pgm"), ("Todos", "*")])
        if not path:
            return
        with open(path) as f:
            text = f.read()
        answer = self.request("identity", text)  # Haskell valida el archivo
        if answer is None:
            return
        self.file_name = path.rsplit("/", 1)[-1]
        self.file_text = answer[1]
        self.set_source(self.file_text, self.file_name)
        self.set_status(f"Haskell validó {self.file_name} en {answer[2]} ms")

    def set_source(self, pgm_text, caption):
        """Cambia la imagen de entrada y limpia lo que dependia de la anterior."""
        self.source = pgm_text
        self.result = None
        self.original_card.show(pgm_text, caption)
        self.result_card.clear()
        self.compression.clear()
        self.refresh_controls()

    def apply(self, command):
        answer = self.request(command, self.source)
        if answer is None:
            return
        _, self.result, ms = answer
        self.result_card.show(self.result, command)
        self.set_status(f"Haskell aplicó {command} en {ms} ms")
        self.refresh_controls()

    def apply_chain(self):
        self.apply("chain " + self.chain_entry.get().replace(" ", ""))

    def compress(self):
        answer = self.request("compress", self.source)
        if answer is None:
            return
        _, body, ms = answer
        self.compression.show(parse_stats(body))
        self.set_status(f"Haskell comprimió la imagen en {ms} ms")

    def continue_from_result(self):
        if self.result is not None:
            self.set_source(self.result, "Resultado de " + self.result_card.caption.cget("text"))

    def reset_to_file(self):
        if self.file_text is not None:
            self.set_source(self.file_text, self.file_name)

    def save_file(self):
        if self.result is None:
            return
        path = filedialog.asksaveasfilename(defaultextension=".pgm", initialdir="output",
                                            filetypes=[("Imágenes PGM", "*.pgm")])
        if path:
            with open(path, "w") as f:
                f.write(self.result)
            self.set_status(f"Guardado en {path}")


if __name__ == "__main__":
    root = tk.Tk()
    App(root)
    root.mainloop()
