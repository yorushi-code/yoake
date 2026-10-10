// KizashiMark.qml — живой знак Code Kizashi для Quickshell (Qt 6, QtQuick.Shapes).
// Геометрия та же, что в макете: модуль u = 16, поле 512, острия на лучах 22.5° и уровнях ±8u,
// дуги через T1/T2 и точку d·u на оси (d = 7…10), золотой ромб 36°. Такт анимации 0.8 s.
//
// Использование:
//   KizashiMark { width: 360; height: 360; accent: ThemeBackend.red }
// Для фиолетового варианта: accent: ThemeBackend.mauve

import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property color accent: "#ff2d55"
    property color light: Qt.lighter(accent, 1.35)
    property color hot: "#fff1f4"
    property bool running: true
    readonly property real beat: 800

    implicitWidth: 256
    implicitHeight: 256

    // Поле 512×512 в координатах макета; видимая область знака 70..442.
    Item {
        id: field
        width: 512
        height: 512
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        scale: Math.min(root.width, root.height) / 372
        transformOrigin: Item.Center

        // ---------- левая связка ----------
        Shape {
            id: leftC
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { id: sLC; origin.x: 202.98; origin.y: 256; xScale: 1 }
            ShapePath {
                id: dashL
                fillColor: "transparent"; strokeColor: root.light; strokeWidth: 1.2
                strokeStyle: ShapePath.DashLine; dashPattern: [2.5, 5]; capStyle: ShapePath.RoundCap
                PathSvg { path: "M202.98 128A130.065 130.065 0 0 0 96.38 246M202.98 384A130.065 130.065 0 0 1 96.38 266" }
            }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { id: sLB; origin.x: 202.98; origin.y: 256; xScale: 1 }
            ShapePath {
                fillColor: "transparent"; strokeColor: root.light; strokeWidth: 2.2; capStyle: ShapePath.RoundCap
                PathSvg { path: "M202.98 128A135.531 135.531 0 0 0 112.53 244M202.98 384A135.531 135.531 0 0 1 112.53 268" }
            }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { id: sLA; origin.x: 202.98; origin.y: 256; xScale: 1 }
            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0; y1: 128; x2: 0; y2: 384
                    GradientStop { position: 0; color: root.accent }
                    GradientStop { position: 0.5; color: Qt.lighter(root.accent, 1.2) }
                    GradientStop { position: 1; color: root.accent }
                }
                PathSvg { path: "M202.98 128A146.745 146.745 0 0 0 202.98 384A168.383 168.383 0 0 1 202.98 128Z" }
            }
            ShapePath {
                fillColor: "transparent"; strokeColor: Qt.rgba(1, 0.95, 0.96, 0.55); strokeWidth: 1.2
                PathSvg { path: "M202.98 128A168.383 168.383 0 0 0 202.98 384" }
            }
        }

        // ---------- правая связка (зеркало) ----------
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { id: sRC; origin.x: 309.02; origin.y: 256; xScale: 1 }
            ShapePath {
                id: dashR
                fillColor: "transparent"; strokeColor: root.light; strokeWidth: 1.2
                strokeStyle: ShapePath.DashLine; dashPattern: [2.5, 5]; capStyle: ShapePath.RoundCap
                PathSvg { path: "M309.02 128A130.065 130.065 0 0 1 415.62 246M309.02 384A130.065 130.065 0 0 0 415.62 266" }
            }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { id: sRB; origin.x: 309.02; origin.y: 256; xScale: 1 }
            ShapePath {
                fillColor: "transparent"; strokeColor: root.light; strokeWidth: 2.2; capStyle: ShapePath.RoundCap
                PathSvg { path: "M309.02 128A135.531 135.531 0 0 1 399.47 244M309.02 384A135.531 135.531 0 0 0 399.47 268" }
            }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { id: sRA; origin.x: 309.02; origin.y: 256; xScale: 1 }
            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0; y1: 128; x2: 0; y2: 384
                    GradientStop { position: 0; color: root.accent }
                    GradientStop { position: 0.5; color: Qt.lighter(root.accent, 1.2) }
                    GradientStop { position: 1; color: root.accent }
                }
                PathSvg { path: "M309.02 128A146.745 146.745 0 0 1 309.02 384A168.383 168.383 0 0 0 309.02 128Z" }
            }
            ShapePath {
                fillColor: "transparent"; strokeColor: Qt.rgba(1, 0.95, 0.96, 0.55); strokeWidth: 1.2
                PathSvg { path: "M309.02 128A168.383 168.383 0 0 1 309.02 384" }
            }
        }

        // ---------- узлы ----------
        Shape {
            id: nodeL
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeColor: "transparent"; fillColor: root.accent; PathSvg { path: "M80 256L112 248L120 256L112 264Z" } }
            ShapePath { strokeColor: "transparent"; fillColor: Qt.lighter(root.accent, 1.25); PathSvg { path: "M80 256L112 248L120 256Z" } }
            ShapePath { id: coreL; strokeColor: "transparent"; fillColor: root.hot; PathSvg { path: "M92 256L112 252L116 256L112 260Z" } }
        }
        Shape {
            id: nodeR
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeColor: "transparent"; fillColor: root.accent; PathSvg { path: "M432 256L400 248L392 256L400 264Z" } }
            ShapePath { strokeColor: "transparent"; fillColor: Qt.lighter(root.accent, 1.25); PathSvg { path: "M432 256L400 248L392 256Z" } }
            ShapePath { strokeColor: "transparent"; fillColor: root.hot; PathSvg { path: "M420 256L400 252L396 256L400 260Z" } }
        }

        // ---------- игла и ромб ----------
        Shape {
            id: needle
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { id: sNeedle; origin.x: 256; origin.y: 256; xScale: 1; yScale: 1 }
            ShapePath {
                fillColor: "transparent"; strokeColor: Qt.rgba(root.light.r, root.light.g, root.light.b, 0.4); strokeWidth: 1.1
                PathSvg { path: "M256 96L307.99 256L256 416L204.01 256Z" }
            }
        }
        Shape {
            id: core
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { id: sCore; origin.x: 256; origin.y: 256; xScale: 1; yScale: 1 }
            ShapePath { strokeColor: "transparent"; fillColor: Qt.lighter(root.accent, 1.2); PathSvg { path: "M254 134.16L214.41 256L254 256Z" } }
            ShapePath { strokeColor: "transparent"; fillColor: Qt.darker(root.accent, 1.35); PathSvg { path: "M254 256L214.41 256L254 377.84Z" } }
            ShapePath { strokeColor: "transparent"; fillColor: Qt.lighter(root.accent, 1.35); PathSvg { path: "M258 134.16L297.59 256L258 256Z" } }
            ShapePath { strokeColor: "transparent"; fillColor: root.accent; PathSvg { path: "M258 256L297.59 256L258 377.84Z" } }
        }
        Shape {
            id: seam
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            opacity: 0.85
            ShapePath { strokeColor: "transparent"; fillColor: root.hot; PathSvg { path: "M256 128L259 256L256 384L253 256Z" } }
        }
    }

    // ---------- движение: всё на такте 0.8 s ----------
    // Дыхание связок волной: лезвие → дуга → нить, сдвиг пол-такта.
    SequentialAnimation {
        loops: Animation.Infinite; running: root.running
        ParallelAnimation {
            NumberAnimation { target: sLA; property: "xScale"; to: 1.035; duration: root.beat * 3; easing.type: Easing.InOutSine }
            NumberAnimation { target: sRA; property: "xScale"; to: 1.035; duration: root.beat * 3; easing.type: Easing.InOutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: sLA; property: "xScale"; to: 1; duration: root.beat * 3; easing.type: Easing.InOutSine }
            NumberAnimation { target: sRA; property: "xScale"; to: 1; duration: root.beat * 3; easing.type: Easing.InOutSine }
        }
    }
    SequentialAnimation {
        loops: Animation.Infinite; running: root.running
        PauseAnimation { duration: root.beat / 2 }
        SequentialAnimation {
            loops: Animation.Infinite
            ParallelAnimation {
                NumberAnimation { target: sLB; property: "xScale"; to: 1.08; duration: root.beat * 3; easing.type: Easing.InOutSine }
                NumberAnimation { target: sRB; property: "xScale"; to: 1.08; duration: root.beat * 3; easing.type: Easing.InOutSine }
                NumberAnimation { target: nodeL; property: "x"; to: -7.28; duration: root.beat * 3; easing.type: Easing.InOutSine }
                NumberAnimation { target: nodeR; property: "x"; to: 7.28; duration: root.beat * 3; easing.type: Easing.InOutSine }
            }
            ParallelAnimation {
                NumberAnimation { target: sLB; property: "xScale"; to: 1; duration: root.beat * 3; easing.type: Easing.InOutSine }
                NumberAnimation { target: sRB; property: "xScale"; to: 1; duration: root.beat * 3; easing.type: Easing.InOutSine }
                NumberAnimation { target: nodeL; property: "x"; to: 0; duration: root.beat * 3; easing.type: Easing.InOutSine }
                NumberAnimation { target: nodeR; property: "x"; to: 0; duration: root.beat * 3; easing.type: Easing.InOutSine }
            }
        }
    }
    SequentialAnimation {
        loops: Animation.Infinite; running: root.running
        PauseAnimation { duration: root.beat }
        SequentialAnimation {
            loops: Animation.Infinite
            ParallelAnimation {
                NumberAnimation { target: sLC; property: "xScale"; to: 1.14; duration: root.beat * 3; easing.type: Easing.InOutSine }
                NumberAnimation { target: sRC; property: "xScale"; to: 1.14; duration: root.beat * 3; easing.type: Easing.InOutSine }
            }
            ParallelAnimation {
                NumberAnimation { target: sLC; property: "xScale"; to: 1; duration: root.beat * 3; easing.type: Easing.InOutSine }
                NumberAnimation { target: sRC; property: "xScale"; to: 1; duration: root.beat * 3; easing.type: Easing.InOutSine }
            }
        }
    }
    // Поток по нитям: пунктир течёт от острий к узлам.
    NumberAnimation { target: dashL; property: "dashOffset"; from: 0; to: -30; duration: root.beat * 3; loops: Animation.Infinite; running: root.running }
    NumberAnimation { target: dashR; property: "dashOffset"; from: 0; to: -30; duration: root.beat * 3; loops: Animation.Infinite; running: root.running }
    // Ромб и игла дышат в противофазе к лезвиям.
    SequentialAnimation {
        loops: Animation.Infinite; running: root.running
        PauseAnimation { duration: root.beat * 3 }
        SequentialAnimation {
            loops: Animation.Infinite
            ParallelAnimation {
                NumberAnimation { target: sCore; properties: "xScale,yScale"; to: 1.025; duration: root.beat * 3; easing.type: Easing.InOutSine }
                NumberAnimation { target: sNeedle; properties: "xScale,yScale"; to: 1.04; duration: root.beat * 3; easing.type: Easing.InOutSine }
            }
            ParallelAnimation {
                NumberAnimation { target: sCore; properties: "xScale,yScale"; to: 1; duration: root.beat * 3; easing.type: Easing.InOutSine }
                NumberAnimation { target: sNeedle; properties: "xScale,yScale"; to: 1; duration: root.beat * 3; easing.type: Easing.InOutSine }
            }
        }
    }
    // Мерцание трещины света.
    SequentialAnimation {
        loops: Animation.Infinite; running: root.running
        NumberAnimation { target: seam; property: "opacity"; to: 1; duration: root.beat * 0.75; easing.type: Easing.InOutSine }
        NumberAnimation { target: seam; property: "opacity"; to: 0.55; duration: root.beat * 0.75; easing.type: Easing.InOutSine }
        NumberAnimation { target: seam; property: "opacity"; to: 0.95; duration: root.beat * 0.75; easing.type: Easing.InOutSine }
        NumberAnimation { target: seam; property: "opacity"; to: 0.85; duration: root.beat * 0.75; easing.type: Easing.InOutSine }
    }
}
