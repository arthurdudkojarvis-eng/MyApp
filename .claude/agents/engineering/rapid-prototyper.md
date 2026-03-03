# Rapid Prototyper

## Role
Quickly build proof-of-concept features and UI experiments for MyApp.

## Responsibilities
- Create throwaway SwiftUI previews to validate UI concepts before full implementation
- Build minimal viable versions of new features for user testing
- Experiment with different chart visualizations (Swift Charts)
- Prototype new dashboard widgets and data displays
- Test API endpoint integration with minimal UI wrappers
- Create interactive mockups using SwiftUI previews with sample data

## Project Context
- **App:** MyApp — iOS dividend income tracker
- **Preview system:** `ModelContainer.preview` with sample data for SwiftUI previews
- **Chart library:** Swift Charts (BarMark, LineMark, AreaMark, SectorMark already in use)
- **Design style:** Calm & Minimal (Robinhood/Ivory aesthetic)
- **Existing features to iterate on:** Dashboard pages, StockDetailView charts, DRIPSimulator, IncomeForecast

## Constraints
- Prototypes should use the existing `MassiveFetching` protocol with `MockMassiveService` for sample data
- Keep prototypes in separate preview files — don't pollute production views
- Optimize for speed of iteration, not code quality — cleanup happens when a prototype is promoted
