# TaskCheck 📝

> **Gestor de tareas y productividad personal local-first para el escritorio Linux.**  
> Diseñado para desarrolladores, creadores y usuarios que priorizan la privacidad, la velocidad y la concentración, sin dependencias de la nube ni servicios externos.

---

## 🚀 Características Principales

- 🔒 **100% Local y Privado**: Sin cuentas, sin telemetría, sin Firebase ni dependencias en la nube. Tus datos residen exclusivamente en tu equipo.
- ⚡ **Rápido y Reactivo**: Motor de base de datos local SQLite con **Drift ORM**, modo **WAL** (Write-Ahead Logging) y claves foráneas activas (`PRAGMA foreign_keys = ON`).
- 📋 **Gestión Integral de Tareas**:
  - Tareas con título, descripción, prioridad (Baja, Normal, Alta, Urgente), fecha límite y estado.
  - Subtareas anidadas con cálculo dinámico de avance porcentual y eliminación en cascada.
  - Categorías personalizables con color y gestión unificada.
- 🗂️ **Filtros y Búsqueda en Tiempo Real**: Filtrado cruzado por categoría, prioridad, estado y texto en tiempo real.
- 📊 **Panel de Estadísticas y Métricas**:
  - KPIs de productividad (Total, Pendientes, En progreso, Completadas, Vencidas, Tasa de finalización).
  - Gráfico de barras interactivo con distribución por prioridad (`fl_chart`).
  - Desglose y porcentaje por categoría.
- 🪟 **Widget Flotante de Escritorio (Desktop Widget)**:
  - Ventana flotante compacta independiente para anclar en tu pantalla de trabajo.
  - Soporte de fijación al frente (`always-on-top`).
  - Acciones rápidas para marcar tareas completadas y saltar a la aplicación principal.
  - Guarda automáticamente su posición y tamaño en pantalla.
- 🎨 **Diseño Moderno y Adaptable**:
  - Temas Claro, Oscuro y Automático según las preferencias del sistema.
  - Interfaz estilizada y ergonómica con paleta refinada y tipografía moderna.
- ⌨️ **Atajos de Teclado**:
  - `Ctrl + N`: Crear nueva tarea.
  - `Ctrl + F`: Enfocar búsqueda.
  - `Ctrl + ,`: Abrir pantalla de configuración.
- 📦 **Copia de Seguridad y Restauración**: Exporta e importa tus datos en formato JSON portable.

---

## 💻 Requisitos del Sistema y Dependencias Linux

### Requisitos:
- **Sistema Operativo:** Ubuntu 22.04 / 24.04 LTS o cualquier distribución Linux moderna compatible con GTK 3.
- **Flutter SDK:** 3.47.7 o superior (canal stable).
- **Dart SDK:** 3.13.5 o superior.
- **Arquitectura:** x86_64 / arm64.

### Dependencias de Compilación en Linux (Ubuntu/Debian):
```bash
sudo apt update
sudo apt install -y clang cmake ninja-build pkg-config \
    libgtk-3-dev liblzma-dev libsqlite3-dev
```

---

## 🛠️ Instalación y Ejecución

### 1. Clonar el repositorio
```bash
git clone https://github.com/tu-usuario/flutter_taskcheck.git
cd flutter_taskcheck
```

### 2. Instalar dependencias de Flutter
```bash
flutter pub get
```

### 3. Generar código de Drift (si no está generado)
```bash
dart run build_runner build
```

### 4. Ejecutar la aplicación en modo desarrollo
```bash
flutter run -d linux
```

### 5. Ejecutar directamente el Widget Flotante de Escritorio
```bash
flutter run -d linux -- --widget
```

---

## 📁 Ubicación de Datos Locales

TaskCheck almacena sus datos de forma segura en las rutas estándar XDG de Linux proporcionadas por `path_provider`:

- **Base de Datos SQLite (`task_check.sqlite`):**
  ```bash
  ~/.local/share/task_check/task_check.sqlite
  ```
- **Preferencias del Usuario (Tema, Dimensiones del Widget):**
  ```bash
  ~/.config/task_check/
  ```

---

## 🏛️ Arquitectura del Proyecto

El proyecto sigue una arquitectura limpia basada en características (**Feature-First Architecture**) combinada con **Riverpod** para la gestión reactiva de estado y **GoRouter** para el enrutamiento:

```text
lib/
├── app.dart                                # MaterialApp con configuración de temas y localización
├── main.dart                               # Punto de entrada (modo normal o --widget)
├── core/
│   ├── constants/app_constants.dart        # Constantes globales de la aplicación
│   ├── database/                           # Capa de base de datos SQLite con Drift
│   │   ├── app_database.dart               # Consultas, streams y migraciones
│   │   ├── connection/connection.dart      # Conexión nativa con WAL y FK ON
│   │   └── tables.dart                     # Tablas Tasks, Subtasks, Categories
│   ├── providers.dart                      # Proveedores Riverpod globales
│   ├── router/app_router.dart              # Rutas declarativas GoRouter y ShellRoute
│   ├── theme/                              # Paletas de color y diseño claro/oscuro
│   └── utils/date_formatter.dart           # Formateador de fechas relativas en español
├── features/
│   ├── archive/presentation/               # Pantalla de tareas archivadas
│   ├── categories/                         # Dominio, datos y diálogo de categorías
│   ├── dashboard/presentation/             # Dashboard principal con métricas
│   ├── desktop_widget/presentation/        # Ventana independiente flotante
│   ├── settings/presentation/              # Configuración, importación y exportación
│   ├── statistics/presentation/            # Pantalla de gráficos y métricas fl_chart
│   ├── subtasks/                           # Gestión y persistencia de subtareas
│   └── tasks/                              # CRUD de tareas, tarjetas y diálogos
└── shared/widgets/app_scaffold.dart        # Barra lateral colapsable y atajos de teclado
```

---

## 🧪 Pruebas Automatizadas

La aplicación incluye un conjunto completo de pruebas unitarias, de persistencia en base de datos y de componentes visuales:

Para ejecutar todas las pruebas:
```bash
flutter test
```

Para ejecutar análisis estático de código:
```bash
flutter analyze
```

---

## 📦 Compilación para Producción (Release)

Para compilar el binario optimizado para Linux:

```bash
flutter build linux --release
```

El ejecutable resultante y sus bibliotecas se encontrarán en:
```text
build/linux/x64/release/bundle/
├── task_check             # Binario ejecutable principal
├── data/                  # Assets y fuentes
└── lib/                   # Bibliotecas compartidas de Flutter y SQLite
```

Puedes ejecutar la versión release directamente con:
```bash
./build/linux/x64/release/bundle/task_check
```

---

## 🪟 Compatibilidad del Widget de Escritorio en Linux

| Entorno de Escritorio | Ventana Flotante | Always-on-top | Persistencia de Posición |
|-----------------------|:----------------:|:-------------:|:------------------------:|
| **GNOME (X11)**       | ✅ Soportado     | ✅ Soportado  | ✅ Soportado             |
| **GNOME (Wayland)**   | ✅ Soportado     | ⚠️ Según compositor | ✅ Soportado       |
| **KDE Plasma (X11)**  | ✅ Soportado     | ✅ Soportado  | ✅ Soportado             |
| **KDE Plasma (Wayland)**| ✅ Soportado   | ⚠️ Según compositor | ✅ Soportado       |
| **XFCE / Cinnamon**   | ✅ Soportado     | ✅ Soportado  | ✅ Soportado             |

> **Nota:** En sesiones Wayland, la política de posicionamiento absoluto de ventanas depende del compositor de la distribución. La aplicación maneja esto de forma tolerante sin bloquearse ni fallar.

---

## ⚠️ Limitaciones Conocidas

- La aplicación es una solución de escritorio local-first; no incluye sincronización automática en red entre múltiples dispositivos distintos (se puede transferir la copia de seguridad JSON manualmente).
- Las funciones de `always-on-top` pueden requerir habilitar permisos en ciertos compositores Wayland estrictos.

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo `LICENSE` para más detalles.
