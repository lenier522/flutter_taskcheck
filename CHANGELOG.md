# Registro de Cambios (Changelog)

Todos los cambios notables en este proyecto serán documentados en este archivo.

El formato se basa en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/) y este proyecto se adhiere a [Semantic Versioning](https://semver.org/lang/es/).

## [1.0.0] - 2026-10-31

### Añadido
- **Arquitectura Local-First Offline**: Persistencia 100% local con SQLite a través de Drift ORM, garantizando integridad referencial (FK ON) y rendimiento con modo WAL.
- **Gestión Completa de Tareas (CRUD)**: Creación, lectura, actualización y eliminación de tareas con título, descripción, prioridad (Baja, Normal, Alta, Urgente), fecha límite y estado.
- **Subtareas Dinámicas**: Desglose jerárquico de tareas en subtareas con checkbox individual y cálculo reactivo de progreso (0% a 100%). Eliminación en cascada garantizada.
- **Categorías Personalizadas**: Organización por categorías con nombres únicos, selector de color y asignación rápida. Integridad referencial con `ON DELETE SET NULL`.
- **Filtros Avanzados y Búsqueda en Tiempo Real**: Filtrado por estado (Pendiente, En progreso, Completada), prioridad, categoría y búsqueda textual por coincidencia en título y descripción.
- **Dashboard y Estadísticas**:
  - Vista general con métricas clave (Total creadas, Pendientes, En progreso, Completadas, Vencidas, Tasa de finalización).
  - Gráfico de barras interactivo con distribución por prioridad (`fl_chart`).
  - Desglose porcentual y barras de progreso por categoría.
  - Columnas de tareas urgentes y próximas a vencer.
- **Archivo Histórico**:
  - Archivado y desarchivado de tareas sin eliminarlas de la base de datos.
  - Eliminación definitiva individual o masiva con cuadro de diálogo de confirmación.
- **Ventana Flotante de Escritorio (Desktop Widget)**:
  - Segunda ventana independiente (`--widget`) optimizada para productividad en Linux.
  - Modo siempre al frente (`always-on-top`) configurable.
  - Arrastrable y redimensionable con persistencia de posición y tamaño en SharedPreferences.
  - Acciones rápidas para completar/reabrir tareas e integración para abrir la aplicación principal.
- **Personalización de Tema**:
  - Soporte completo para temas Claro, Oscuro y de Sistema con cambio reactivo instantáneo.
- **Atajos de Teclado Globales**:
  - `Ctrl+N`: Nueva tarea rápida.
  - `Ctrl+F`: Búsqueda instantánea.
  - `Ctrl+,`: Acceso a configuración.
- **Exportación e Importación**:
  - Respaldo completo de la base de datos a formato JSON.
  - Restauración segura validada.
- **Suite de Pruebas Automatizadas**:
  - Pruebas unitarias para modelos de dominio (`Task`, `Subtask`, `Category`, `DateFormatter`).
  - Pruebas de base de datos SQLite en memoria con Drift (`NativeDatabase.memory()`).
  - Pruebas de widgets (`TaskCard`).
