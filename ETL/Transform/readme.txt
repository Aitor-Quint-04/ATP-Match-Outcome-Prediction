Due to compute and budget constraints, I limited the Python extractor to matches played between 1999 and 2025. 
To preserve historical context, I perform a **pre-seeding** of metrics using datasets from 1968–1998 
sourced from Jeff Sackmann, integrating them after normalization (types, keys, surfaces, categories, player/tournament 
codes) and quality checks. This is a pragmatic solution that enables historical features without re-scraping the entire 
past. That said, if you have the resources and time, I strongly recommend running the Python extractor across the full 
history and skipping pre-seeding, computing all statistics from your own scraped datasets. 
This yields maximum schema consistency, avoids definition drift between sources, and improves end-to-end reproducibility. 
My pipeline supports both approaches; pre-seeding is simply a responsible shortcut up to 1998.
