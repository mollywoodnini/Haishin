//
//  CGFloat+Additions.swift
//  Haishin
//
//  Created by Tan Nghia La on 24.01.26.
//

import CoreGraphics

extension CGFloat {
    
    /// The `spacing-xxs` styleguide constant.
    static let spacingXXS = CGFloat(4)
    
    /// The `spacing-xs` styleguide constant.
    static let spacingXS = CGFloat(8)
    
    /// The `spacing-s` styleguide constant.
    static let spacingS = CGFloat(16)
    
    /// The `spacing-m` styleguide constant.
    static let spacingM = CGFloat(24)
    
    /// The `spacing-l` styleguide constant.
    static let spacingL = CGFloat(48)
    
    /// The default spacing for all layout elements.
    static let standardSpacing = CGFloat.spacingS
    
    /// The defaut spacing for all text elements.
    static let textStandardSpacing = CGFloat.spacingM
        
    /// The minium alpha value of a view.
    static let minAlpha = CGFloat(0)
    
    /// The maximum alpha value of a view.
    static let maxAlpha = CGFloat(1)
    
    /// The alpha value of a disabled view.
    static let disabledAlpha = CGFloat(0.5)
    
    /// The alpha value of a disabled button.
    static let disabledButtonAlpha = CGFloat(0.3)
    
    /// The default button height.
    static let defaultButtonHeight = CGFloat(56)
    
    /// The default width for borders.
    static let defaultBorderWidth = CGFloat(1)
    
    /// The default scale for animation when a button is pressed.
    static let defaultPressingScale: CGFloat = 0.97
    
    /// The `xs` corner radius constant.
    /// The extra small radius is for our smallest components until a height of 24px like our checkbox.
    static let cornerRadiusXS = CGFloat(4)
    
    /// The `s` corner radius constant.
    /// The small radius is also for components with a height from 24 until 40px.
    static let cornerRadiusS = CGFloat(8)
    
    /// The `m` corner radius constant.
    /// The default radius applies to accordions, inputs and tooltips and components with heights of 48px and larger.
    static let cornerRadiusM = CGFloat(16)
    
    /// The `l` corner radius constant.
    /// The large radius applies to more extensive components like modals, teasers and service cards.
    static let cornerRadiusL = CGFloat(24)
}
