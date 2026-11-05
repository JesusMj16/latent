"""Interfaz grafica (solo interfaz).

Python NO procesa la imagen: elige el archivo, manda el texto PGM al
servidor Haskell por un socket TCP, recibe la respuesta y la muestra.
Todos los filtros, la compresion y la validacion viven en Haskell.
"""
import socket
import tkinter as tk
from tkinter import filedialog, messagebox

HOST, PORT = "127.0.0.1", 5000
VIEW_SIZE = 400  # tamano aproximado de cada panel en pantalla


def ask_server(command, pgm_text):
    """Manda 'comando + PGM' al servidor y regresa su respuesta como texto."""
    with socket.create_connection((HOST, PORT), timeout=10) as conn:
        conn.sendall((command + "\n" + pgm_text).encode("ascii"))
        conn.shutdown(socket.SHUT_WR)  # avisa a Haskell que ya terminamos de mandar
        chunks = []
        while True:
            chunk = conn.recv(65536)
            if not chunk:
                break
            chunks.append(chunk)
    return b"".join(chunks).decode("ascii")


def p2_to_photo(pgm_text):
    """Convierte P2 (texto) a P5 (binario) SOLO para mostrarlo.

    Esto NO es un filtro: los valores de los pixeles no cambian, solo se
    escriben como bytes, porque PhotoImage de Tk no lee P2 de texto.
    """
    lines = [l for l in pgm_text.splitlines() if not l.startswith("#")]
    tokens = " ".join(lines).split()
    w, h = int(tokens[1]), int(tokens[2])
    header = ("P5\n%d %d\n255\n" % (w, h)).encode("ascii")
    photo = tk.PhotoImage(data=header + bytes(int(t) for t in tokens[4:]))
    zoom = max(1, VIEW_SIZE // max(w, h))  # ampliar imagenes pequenas
    return photo.zoom(zoom) if zoom > 1 else photo


class App:
    def __init__(self, root):
        self.root = root
        self.original = None  # texto PGM abierto
        self.result = None    # texto PGM que regreso Haskell
        root.title("latent: filtros funcionales en Haskell")

        bar = tk.Frame(root)
        bar.pack(fill="x", padx=6, pady=4)
        tk.Button(bar, text="Abrir PGM", command=self.open_file).pack(side="left")
        tk.Button(bar, text="Guardar resultado", command=self.save_file).pack(side="left")
        tk.Button(bar, text="Usar resultado como original", command=self.use_result).pack(side="left")

        simple = tk.Frame(root)
        simple.pack(fill="x", padx=6)
        for label, command in [("Negativo", "negative"), ("Espejo H", "mirrorHorizontal"),
                               ("Espejo V", "mirrorVertical"), ("Rotar der", "rotateRight"),
                               ("Rotar izq", "rotateLeft"), ("Desenfoque", "blur")]:
            tk.Button(simple, text=label, command=lambda c=command: self.run(c)).pack(side="left")

        params = tk.Frame(root)
        params.pack(fill="x", padx=6, pady=4)
        self.bright = self.param_entry(params, "Brillo", "40", "brightness")
        self.thresh = self.param_entry(params, "Umbral", "128", "threshold")

        chain = tk.Frame(root)
        chain.pack(fill="x", padx=6)
        tk.Label(chain, text="chain").pack(side="left")
        self.chain = tk.Entry(chain, width=50)
        self.chain.insert(0, "brightness:30,rotateRight,threshold:128")
        self.chain.pack(side="left")
        tk.Button(chain, text="Aplicar cadena",
                  command=lambda: self.run("chain " + self.chain.get().replace(" ", ""))).pack(side="left")
        tk.Button(chain, text="Comprimir (RLE)", command=self.compress).pack(side="left", padx=8)

        panels = tk.Frame(root)
        panels.pack(padx=6, pady=6)
        self.left = tk.Label(panels, text="Original", width=50, height=22, relief="groove", compound="top")
        self.right = tk.Label(panels, text="Resultado", width=50, height=22, relief="groove", compound="top")
        self.left.pack(side="left", padx=4)
        self.right.pack(side="left", padx=4)

        self.status = tk.Label(root, text="Abre un archivo PGM P2 para empezar", anchor="w")
        self.status.pack(fill="x", padx=6, pady=4)

    def param_entry(self, parent, label, default, command):
        """Crea un campo con su boton; el valor se manda tal cual a Haskell."""
        entry = tk.Entry(parent, width=6)
        entry.insert(0, default)
        tk.Button(parent, text=label, command=lambda: self.run(command + " " + entry.get().strip())).pack(side="left")
        entry.pack(side="left", padx=(0, 10))
        return entry

    def show(self, widget, pgm_text, caption):
        photo = p2_to_photo(pgm_text)
        widget.configure(image=photo, text=caption, width=0, height=0)
        widget.image = photo  # guardar referencia para que Tk no la borre

    def open_file(self):
        path = filedialog.askopenfilename(filetypes=[("PGM", "*.pgm"), ("Todos", "*")])
        if not path:
            return
        with open(path) as f:
            self.original = f.read()
        # Haskell valida el archivo: si el PGM esta mal, responde ERROR
        self.result = None
        answer = self.request("identity")
        if answer is None:
            self.original = None
        else:
            self.original = answer.split("\n", 1)[1]  # PGM ya validado por Haskell
            self.show(self.left, self.original, "Original: " + path.split("/")[-1])
            self.status.configure(text="Abierto " + path)

    def request(self, command):
        """Pide algo al servidor; maneja servidor apagado y respuestas ERROR."""
        if self.original is None:
            messagebox.showinfo("latent", "Primero abre un archivo PGM")
            return None
        try:
            answer = ask_server(command, self.original)
        except OSError:
            messagebox.showerror("latent", "No hay conexion con Haskell.\nArranca el servidor con ./run.sh")
            return None
        if answer.startswith("ERROR"):
            messagebox.showerror("latent", "Haskell respondio:\n" + answer)
            return None
        return answer

    def run(self, command):
        answer = self.request(command)
        if answer is not None:
            self.result = answer.split("\n", 1)[1]  # quitar la linea IMAGE
            self.show(self.right, self.result, "Resultado: " + command)
            self.status.configure(text="Haskell aplico: " + command)

    def compress(self):
        answer = self.request("compress")
        if answer is not None:
            stats = dict(l.split(" ", 1) for l in answer.splitlines()[1:] if " " in l)
            self.status.configure(text="RLE: original %s enteros, comprimido %s enteros (%s%%), "
                                       "%s rachas, ida y vuelta correcta: %s"
                                       % (stats["originalSize"], stats["compressedSize"], stats["percent"],
                                          stats["runs"], stats["roundTrip"]))

    def save_file(self):
        if self.result is None:
            messagebox.showinfo("latent", "Todavia no hay resultado para guardar")
            return
        path = filedialog.asksaveasfilename(defaultextension=".pgm", initialdir="output")
        if path:
            with open(path, "w") as f:
                f.write(self.result)
            self.status.configure(text="Guardado " + path)

    def use_result(self):
        if self.result is not None:
            self.original = self.result
            self.show(self.left, self.original, "Original: resultado anterior")


if __name__ == "__main__":
    root = tk.Tk()
    App(root)
    root.mainloop()
