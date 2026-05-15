
--
-- Indexes for dumped tables
--

--
-- Indexes for table `ar`
--
ALTER TABLE `ar`
  ADD PRIMARY KEY (`recommender`);

--
-- Indexes for table `rec2rec`
--
ALTER TABLE `rec2rec`
  ADD PRIMARY KEY (`recommender`,`recommendee`);

--
-- Indexes for table `rec2sp`
--
ALTER TABLE `rec2sp`
  ADD PRIMARY KEY (`recommender`,`recommendee`);
