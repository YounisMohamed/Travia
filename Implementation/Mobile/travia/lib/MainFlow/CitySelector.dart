import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:travia/Helpers/AppColors.dart';

// Tourism data
// Tourism data
final tourismData = {
  'Asia': {
    'China': ['Shanghai'],
    'United Arab Emirates': ['Dubai'],
  },
  'Europe': {
    'France': ['Paris'],
    'Italy': ['Rome'],
    'Germany': ['Berlin'],
    'Spain': ['Barcelona'],
    'Russia': ['Moscow'],
  },
  'North America': {
    'USA': ['New York', 'Los Angeles'],
    'Mexico': ['Mexico City'],
    'Canada': ['Toronto'],
  },
  'South America': {
    'Brazil': ['Rio de Janeiro'],
  },
};

// Flag emoji map
final countryFlagMap = {
  'China': '🇨🇳',
  'United Arab Emirates': '🇦🇪',
  'Russia': '🇷🇺',
  'France': '🇫🇷',
  'Italy': '🇮🇹',
  'Germany': '🇩🇪',
  'Spain': '🇪🇸',
  'USA': '🇺🇸',
  'Mexico': '🇲🇽',
  'Canada': '🇨🇦',
  'Brazil': '🇧🇷',
};

// Country positions (normalized 0-1)
final countryPositions = {
  'Asia': {
    'China': Offset(0.5, 0.5),
    'United Arab Emirates': Offset(0.2, 0.55),
  },
  'Europe': {
    'France': Offset(0.3, 0.57),
    'Italy': Offset(0.4, 0.64),
    'Germany': Offset(0.4, 0.53),
    'Spain': Offset(0.14, 0.62),
    'Russia': Offset(0.7, 0.45),
  },
  'North America': {
    'USA': Offset(0.5, 0.5),
    'Mexico': Offset(0.4, 0.6),
    'Canada': Offset(0.5, 0.35),
  },
  'South America': {
    'Brazil': Offset(0.62, 0.43),
  },
};

class CitySelector extends ConsumerStatefulWidget {
  @override
  ConsumerState<CitySelector> createState() => _CitySelectorState();
}

class _CitySelectorState extends ConsumerState<CitySelector> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final continents = ['Asia', 'Europe', 'North America', 'South America'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: continents.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select Destination',
          style: GoogleFonts.lexendDeca(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(50),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: kDeepPink,
            unselectedLabelColor: Colors.grey,
            indicatorColor: kDeepPink,
            labelStyle: GoogleFonts.lexendDeca(fontWeight: FontWeight.w600),
            tabs: continents.map((continent) => Tab(text: continent)).toList(),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: continents.map((continent) => _buildContinentView(continent)).toList(),
      ),
    );
  }

  Widget _buildContinentView(String continent) {
    final countries = tourismData[continent] ?? {};
    final positions = countryPositions[continent] ?? {};

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return GestureDetector(
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.globalPosition);
            final offset = Offset(local.dx / width, local.dy / height);
            print('Tapped at: $offset');
          },
          child: Stack(
            children: [
              // SVG Background
              Positioned.fill(
                child: SvgPicture.asset(
                  'assets/${continent.replaceAll(' ', '_')}.svg',
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                ),
              ),

              // Country Indicators
              ...countries.keys.map((country) {
                final position = positions[country] ?? Offset(0.5, 0.5);
                final dx = position.dx * width;
                final dy = position.dy * height;

                return Positioned(
                  left: dx - 20, // Center the circle
                  top: dy - 20,
                  child: GestureDetector(
                    onTap: () => _showCityDialog(country, countries[country] ?? []),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: FittedBox(
                          child: Text(
                            countryFlagMap[country] ?? '🏳️',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 19,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  void _showCityDialog(String country, List<String> cities) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: kBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 5,
              margin: EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                children: [
                  Text(
                    countryFlagMap[country] ?? '🏳️',
                    style: TextStyle(fontSize: 32),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Cities in $country",
                          style: GoogleFonts.lexendDeca(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: kDeepPink,
                          ),
                        ),
                        Text(
                          "Select your destination",
                          style: GoogleFonts.lexendDeca(
                            fontSize: 14,
                            color: kBlack.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 24),
                itemCount: cities.length,
                itemBuilder: (context, index) {
                  final city = cities[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context); // Close bottom sheet
                      Navigator.pop(context, city); // Return selected city
                    },
                    child: Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: kWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: kDeepPink.withOpacity(0.2),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kDeepPink.withOpacity(0.05),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [kDeepPink, kDeepPinkLight],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.location_city,
                              color: kWhite,
                              size: 24,
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              city,
                              style: GoogleFonts.lexendDeca(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: kBlack,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: kDeepPink,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
