#Futuras mejoras

Meter ingresos
Que te muestre el balance total, lo gastado, trayectoria, etc. 
Poder poner gastos recurrentes
Pestaña de gráficas circulares con categorías, meses/año, etc. 
Más categorías
Marcar objetivos y que te diga cómo vas
Gastos compartidos (tipo tricount)


# 💰 Control de Gastos - Flutter App

![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)
![SQLite](https://img.shields.io/badge/sqlite-%2307405e.svg?style=for-the-badge&logo=sqlite&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-000000?style=for-the-badge&logo=ios&logoColor=white)

Una aplicación móvil moderna, rápida y eficiente para el seguimiento de finanzas personales. Permite registrar gastos, visualizar estadísticas detalladas y exportar datos a Excel, todo funcionando de manera local y segura en tu dispositivo (Android & iOS).

## ✨ Características Principales

* **⚡ Rendimiento Nativo:** Base de datos local **SQLite** (`sqflite`) para un manejo instantáneo de miles de registros sin latencia.
* **📊 Análisis Visual:** Gráficas de barras interactivas con degradados (`fl_chart`) para visualizar gastos por **Semana, Mes, Año o Rango Personalizado**.
* **📂 Organización:** Categorización de gastos con iconos y colores distintivos (Comida, Transporte, Ocio, Casa, Salud, Otros).
* **📥 Exportación de Datos:** Generación de reportes en **Excel (.csv)** y función de compartir nativa (WhatsApp, Email, AirDrop, Archivos).
* **📅 Calendario Inteligente:** Filtros de fecha avanzados y selector de rangos personalizado con soporte completo en español.
* **🎨 UI/UX Moderna:** Diseño limpio basado en Material 3, tarjetas con sombras suaves y feedback visual.

## 🛠️ Tecnologías y Librerías

Este proyecto utiliza las siguientes dependencias clave:

* **`sqflite` & `path`:** Persistencia de datos local robusta (SQL).
* **`fl_chart`:** Gráficas estadísticas avanzadas y bonitas.
* **`share_plus` & `path_provider`:** Gestión de archivos y sistema de compartir nativo del móvil.
* **`csv`:** Algoritmo para generar hojas de cálculo compatibles con Excel.
* **`intl` & `flutter_localizations`:** Formato de fechas y soporte de idioma (Español).

## 🚀 Instalación y Ejecución

Sigue estos pasos para correr el proyecto en tu máquina local:

1.  **Clonar el repositorio:**
    ```bash
    git clone [https://github.com/TU_USUARIO/app-control-gastos.git](https://github.com/TU_USUARIO/app-control-gastos.git)
    cd app-control-gastos
    ```

2.  **Instalar dependencias:**
    ```bash
    flutter pub get
    ```

3.  **Configuración para iOS (Solo si usas Mac):**
    Es necesario instalar los pods para que la base de datos funcione en iPhone:
    ```bash
    cd ios
    pod install
    cd ..
    ```

4.  **Ejecutar la App:**
    ```bash
    flutter run
    ```

## 📂 Estructura del Proyecto

Actualmente, el proyecto utiliza una arquitectura simplificada para facilitar el aprendizaje, concentrando la lógica en el archivo principal.

```text
lib/
└── main.dart       # Contiene toda la lógica: Base de datos, Modelos, UI y Gráficas.
pubspec.yaml        # Gestión de dependencias y configuración.
android/            # Código nativo generado para Android.
ios/                # Código nativo generado para iOS.
