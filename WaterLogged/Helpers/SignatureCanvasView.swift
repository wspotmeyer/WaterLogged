//
//  SignatureCanvasView.swift
//  WaterLogged
//
//  Copyright © 2026 John Meyer.
//
//  This file is part of WaterLogged, a scuba dive logging application written by John Meyer.
//
//  WaterLogged is free software: you can redistribute it and/or modify it under the terms of the GNU
//  General Public License as published by the Free Software Foundation, either version 3 of the License,
//  or (at your option) any later version.
//
//  WaterLogged is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
//  even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
//  General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with WaterLogged. If not,
//  see <https://www.gnu.org/licenses/>.

#if !os(macOS)
import SwiftUI
import PencilKit

struct SignatureCanvasView: UIViewRepresentable {
	@Binding var drawing: PKDrawing

	func makeUIView(context: Context) -> PKCanvasView {
		let canvas = PKCanvasView()
		canvas.drawingPolicy = .anyInput
		canvas.tool = PKInkingTool(.pen, color: .label, width: 2)
		canvas.drawing = drawing
		canvas.delegate = context.coordinator
		canvas.backgroundColor = .clear
		canvas.isOpaque = false
		canvas.isScrollEnabled = false

		// Deferred so the canvas is in the view hierarchy when this runs
		Task {
			canvas.becomeFirstResponder()
			// Make ancestor scroll views (e.g. the Form) yield to the
			// canvas's drawing gesture so Apple Pencil input isn't intercepted.
			var ancestor: UIView? = canvas.superview
			while let view = ancestor {
				if let scrollView = view as? UIScrollView {
					scrollView.panGestureRecognizer
						.require(toFail: canvas.drawingGestureRecognizer)
				}
				ancestor = view.superview
			}
		}

		return canvas
	}

	func updateUIView(_ uiView: PKCanvasView, context: Context) {
		if uiView.drawing != drawing {
			uiView.drawing = drawing
		}
	}

	func makeCoordinator() -> Coordinator {
		Coordinator(drawing: $drawing)
	}

	final class Coordinator: NSObject, PKCanvasViewDelegate {
		@Binding var drawing: PKDrawing

		init(drawing: Binding<PKDrawing>) {
			_drawing = drawing
		}

		func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
			drawing = canvasView.drawing
		}
	}
}
#endif
