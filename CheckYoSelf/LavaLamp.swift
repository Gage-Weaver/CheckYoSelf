//
//  LavaLamp.swift
//  CheckYoSelf
//
//  Created by Carlos Mbendera on 29/03/2025.
//

import SwiftUI

struct LavaLamp: View {
    @State private var mainPosition: CGPoint = .zero
    @State private var positions: [CGPoint] = []
    
    private let blurRadius = 20.0
    private let alphaThreshold = 0.875
    private let ballCount = 20
    
    var body: some View {
        Rectangle()
            .fill(.black.gradient)
            .mask {
                TimelineView(.animation(minimumInterval: 0.75)) { timeline in
                    let currentDate = timeline.date.timeIntervalSinceReferenceDate
                    let randomSeed = Int(currentDate / 0.75)
                    
                    GeometryReader { geometry in
                        let size = geometry.size
                        
                        Canvas { context, canvasSize in
                            let circles = (0...positions.count-1).map { tag in
                                context.resolveSymbol(id: tag)!
                            }
                            context.addFilter(.alphaThreshold(min: alphaThreshold))
                            context.addFilter(.blur(radius: blurRadius))
                            context.drawLayer { context2 in
                                circles.forEach { circle in
                                    context2.draw(circle,
                                                  at: .init(x: canvasSize.width/2,
                                                            y: canvasSize.height/2)
                                    )
                                }
                            }
                        } symbols: {
                            ForEach(positions.indices, id: \.self) { id in
                                Circle()
                                    .frame(width: id == 0 ? size.width/2 - blurRadius/alphaThreshold : size.width/4)
                                    .offset(x: id == 0 ? mainPosition.x : positions[id].x,
                                            y: id == 0 ? mainPosition.y : positions[id].y)
                                    .tag(id)
                            }
                        }
                        .onChange(of: randomSeed) { _, _ in
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                mainPosition = randomPosition(in: size, ballSize: .init(width: size.width/4, height: size.width/4))
                                positions = (0..<ballCount).map { _ in
                                    randomPosition(in: size, ballSize: .init(width: size.width/2, height: size.width/2))
                                }
                            }
                        }
                        .onAppear {
                            positions = Array(repeating: .zero, count: ballCount)
                            
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                mainPosition = randomPosition(in: size, ballSize: .init(width: size.width/4, height: size.width/4))
                                positions = positions.map { _ in
                                    randomPosition(in: size, ballSize: .init(width: size.width/2, height: size.width/2))
                                }
                            }
                        }
                    }
                    .shadow(radius: 5, x: -5, y: 7)
                }
            }
            .background(Color.init(red: 0.9, green: 0.9, blue: 1.0))
    }
}

func randomPosition(in bounds: CGSize, ballSize: CGSize) -> CGPoint {
    let xRange = ballSize.width / 2 ... bounds.width - ballSize.width / 2
    let yRange = ballSize.height / 2 ... bounds.height - ballSize.height / 2
    
    let randomX = CGFloat.random(in: xRange)
    let randomY = CGFloat.random(in: yRange)
    
    let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
    
    let offsetX = randomX - center.x
    let offsetY = randomY - center.y
    
    print("random position: x: \(offsetX) y: \(offsetY)")
    
    return CGPoint(x: offsetX, y: offsetY)
}
